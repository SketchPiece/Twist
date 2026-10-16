import DeviceActivity
import FamilyControls
import ManagedSettings
import Observation
import SwiftUI
import UserNotifications

@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    enum Screen: Equatable { case onboarding, home, locked, unwind, opened }

    private(set) var session: Session? = Session.current
    var unwinding = false
    /// After an unwind in a ring: who unwound (nil for this iPhone). Shows the summary.
    var opened: Opened?
    struct Opened: Equatable { var by: Device? }
    /// The device that started this lock, when it wasn't this iPhone.
    private(set) var lockedBy: Device?
    var onboarded: Bool = Shared.defaults.bool(forKey: "onboarded") {
        didSet { Shared.defaults.set(onboarded, forKey: "onboarded") }
    }
    /// Apps that stay open during a session.
    var allowlist: FamilyActivitySelection = AppModel.loadAllowlist() {
        didSet { saveAllowlist() }
    }
    var lastError: String?

    let hub = Hub.shared
    private let store = ManagedSettingsStore(named: .init(Shared.storeName))
    private let center = DeviceActivityCenter()

    init() {
        hub.onDoc = { [weak self] in self?.remote($0) }
        hub.acceptsPairing = { [weak self] in self?.session == nil }
    }

    var screen: Screen {
        if !onboarded { return .onboarding }
        guard session != nil else { return opened != nil ? .opened : .home }
        return unwinding ? .unwind : .locked
    }

    // MARK: - Session

    func start(minutes: Int) async {
        lastError = nil
        // authorizationStatus reads .notDetermined for a moment after launch (and after an
        // update), even when access is granted. Ask again instead of trusting it: this returns
        // at once when access is already there, and only a real refusal sends you back to setup.
        if AuthorizationCenter.shared.authorizationStatus != .approved {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            } catch {
                onboarded = false
                return
            }
        }
        let now = Date()
        await lock(Session(start: now, end: now.addingTimeInterval(TimeInterval(minutes * 60))), by: nil)
    }

    /// Shields, the end-of-session monitor and the VPN. `by` is the device that locked,
    /// nil for this iPhone, which then tells the ring before the VPN cuts the network.
    /// Returns false if the lock could not be put fully in place.
    @discardableResult
    private func lock(_ s: Session, by device: Device?) async -> Bool {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { return false }
        Session.current = s
        lockedBy = device
        opened = nil

        store.shield.applicationCategories = .all(except: allowlist.applicationTokens)
        store.shield.webDomainCategories = .all(except: allowlist.webDomainTokens)
        store.application.denyAppRemoval = true

        let cal = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(parts, from: Date()),
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

        withAnimation(.smooth(duration: 0.5)) {
            session = s
            unwinding = false
        }

        if device == nil { await hub.publish(session: s) }
        await LiveLock.show(s, by: device)

        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        do {
            try await VPN.start()
            return true
        } catch {
            print("VPN start failed: \(error)")
            return false
        }
    }

    /// The lock is over on this iPhone: time ran out, or another device unwound it.
    func end() {
        store.clearAllSettings()
        center.stopMonitoring()
        Session.current = nil
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        withAnimation(.smooth(duration: 0.5)) {
            session = nil
            unwinding = false
            lockedBy = nil
        }
        Task {
            await LiveLock.hide()
            await VPN.stop()
        }
    }

    /// Held all the way through here: open every device in the ring.
    func unwind() {
        let ring = hub.inRing
        end()
        if ring { opened = Opened(by: nil) }
        Task {
            await VPN.stop()
            await hub.publish(session: nil)
        }
    }

    func closeOpened() {
        withAnimation(.smooth(duration: 0.4)) { opened = nil }
    }

    // MARK: - The ring

    /// Another device changed the shared lock or the members.
    private func remote(_ doc: RingDoc) {
        let mine = Session.current
        if let s = doc.session, !s.isOver {
            guard mine != s else { return }
            let by = doc.member(doc.sessionBy)
            Task {
                let ok = await lock(s, by: by)
                if UIApplication.shared.applicationState != .active || !ok {
                    notify(locked: s, by: by, ok: ok)
                }
            }
        } else if let mine, doc.session == nil, doc.sessionChanged > mine.start {
            end()
            withAnimation(.smooth(duration: 0.4)) { opened = Opened(by: doc.member(doc.sessionBy)) }
        }
    }

    private func notify(locked s: Session, by: Device?, ok: Bool) {
        let name = by?.name ?? "Another device"
        let content = UNMutableNotificationContent()
        if ok {
            content.title = "Locked with \(name)"
            content.body = "Until \(TimeText.time(s.end)). Unwinding on any device opens them all."
        } else {
            content.title = "\(name) locked until \(TimeText.time(s.end))"
            content.body = "Tap to lock this iPhone too."
        }
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "twist.ring", content: content, trigger: nil))
    }

    /// Foreground: watch the local network and catch up with iCloud.
    func becameActive() {
        refresh()
        if hub.inRing {
            hub.start()
            Task {
                await Cloud.setUp()
                await hub.pull()
            }
        }
    }

    func wentToBackground() {
        hub.stop()
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
            Task {
                await LiveLock.hide()
                await VPN.stop()
            }
        } else if let s {
            session = s
            // A lock that arrived in the background may not have got its VPN up.
            Task {
                await LiveLock.show(s, by: lockedBy)
                await VPN.ensureRunning()
            }
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

    /// Picking a whole category in the picker should keep every app in it open.
    /// Shields can only exempt apps, so the selection expands categories into app tokens.
    private static func loadAllowlist() -> FamilyActivitySelection {
        var sel = FamilyActivitySelection(includeEntireCategory: true)
        if let data = Shared.defaults.data(forKey: "allowlist"),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            sel.applicationTokens = saved.applicationTokens
            sel.categoryTokens = saved.categoryTokens
            sel.webDomainTokens = saved.webDomainTokens
        }
        return sel
    }

    private func saveAllowlist() {
        if let data = try? JSONEncoder().encode(allowlist) {
            Shared.defaults.set(data, forKey: "allowlist")
        }
    }
}
