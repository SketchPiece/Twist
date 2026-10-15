import DeviceActivity
import FamilyControls
import ManagedSettings
import Observation
import SwiftUI
import UserNotifications

@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    enum Screen: Equatable { case onboarding, home, locked, unwind }

    private(set) var session: Session? = Session.current
    var unwinding = false
    var onboarded: Bool = Shared.defaults.bool(forKey: "onboarded") {
        didSet { Shared.defaults.set(onboarded, forKey: "onboarded") }
    }
    /// Apps that stay open during a session.
    var allowlist: FamilyActivitySelection = AppModel.loadAllowlist() {
        didSet { saveAllowlist() }
    }
    var lastError: String?

    private let store = ManagedSettingsStore(named: .init(Shared.storeName))
    private let center = DeviceActivityCenter()

    var screen: Screen {
        if !onboarded { return .onboarding }
        guard session != nil else { return .home }
        return unwinding ? .unwind : .locked
    }

    // MARK: - Session

    func start(minutes: Int) async {
        lastError = nil
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            onboarded = false
            return
        }
        let now = Date()
        let s = Session(start: now, end: now.addingTimeInterval(TimeInterval(minutes * 60)))
        Session.current = s

        store.shield.applicationCategories = .all(except: allowlist.applicationTokens)
        store.shield.webDomainCategories = .all(except: allowlist.webDomainTokens)
        store.application.denyAppRemoval = true

        let cal = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(parts, from: now),
            intervalEnd: cal.dateComponents(parts, from: s.end),
            repeats: false
        )
        do {
            center.stopMonitoring()
            try center.startMonitoring(.init(Shared.activityName), during: schedule)
        } catch {
            // The app and the tunnel still end the session on time.
            print("startMonitoring failed: \(error)")
        }

        withAnimation(.smooth(duration: 0.5)) { session = s }

        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        do { try await VPN.start() } catch { print("VPN start failed: \(error)") }
    }

    func end() {
        store.clearAllSettings()
        center.stopMonitoring()
        Session.current = nil
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        withAnimation(.smooth(duration: 0.5)) {
            session = nil
            unwinding = false
        }
        Task { await VPN.stop() }
    }

    /// Called whenever the app comes to the foreground.
    func refresh() {
        let s = Session.current
        if let s, s.isOver {
            end()
        } else if s == nil {
            if session != nil { withAnimation { session = nil; unwinding = false } }
            // The monitor may have ended the session while we were away; turn the VPN off.
            store.clearAllSettings()
            Task { await VPN.stop() }
        } else {
            session = s
        }
    }

    func openUnwind() {
        refresh()
        guard session != nil else { return }
        withAnimation(.smooth(duration: 0.4)) { unwinding = true }
    }

    func closeUnwind() {
        withAnimation(.smooth(duration: 0.4)) { unwinding = false }
    }

    // MARK: - Allowlist

    private static func loadAllowlist() -> FamilyActivitySelection {
        guard let data = Shared.defaults.data(forKey: "allowlist"),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return sel
    }

    private func saveAllowlist() {
        if let data = try? JSONEncoder().encode(allowlist) {
            Shared.defaults.set(data, forKey: "allowlist")
        }
    }
}
