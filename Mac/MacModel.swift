import Observation
import ServiceManagement
import SwiftUI

@MainActor @Observable
final class MacModel {
    static let shared = MacModel()

    private(set) var session: Session? = Session.current
    var unwinding = false
    /// The device that started this lock, when it wasn't this Mac.
    private(set) var lockedBy: Device?
    /// Set for a moment when another device unwound the lock: the screens say who.
    private(set) var openedBy: Device?

    let hub = Hub.shared
    @ObservationIgnored private lazy var lockdown = Lockdown(model: self)

    init() {
        hub.onDoc = { [weak self] in self?.remote($0) }
        hub.acceptsPairing = { [weak self] in self?.session == nil }
    }

    // MARK: - Session

    func start(minutes: Int) {
        start(seconds: TimeInterval(minutes * 60))
    }

    func start(seconds: TimeInterval) {
        let now = Date()
        let s = Session(start: now, end: now.addingTimeInterval(seconds))
        lock(s, by: nil)
        Task { await hub.publish(session: s) }
    }

    private func lock(_ s: Session, by device: Device?) {
        Session.current = s
        session = s
        lockedBy = device
        openedBy = nil
        unwinding = false
        lockdown.engage()
    }

    /// The lock is over here: time ran out, or another device unwound it.
    func end() {
        // Released first, so the fade starts from what the screens show now.
        lockdown.release()
        Session.current = nil
        session = nil
        unwinding = false
        lockedBy = nil
        openedBy = nil
        syncLoginItem()
    }

    /// Held all the way through on this Mac: open every device in the ring.
    func unwind() {
        end()
        Task { await hub.publish(session: nil) }
    }

    /// On launch (including after a restart): a running session locks the Mac again.
    func resume() {
        syncLoginItem()
        // Always visible nearby, so an iPhone can find this Mac to add it.
        hub.start()
        if hub.inRing {
            hub.startPolling(every: 60)
            Task {
                await Cloud.setUp()
                await hub.pull()
            }
        }
        guard let s = Session.current else { return }
        if s.isOver {
            end()
        } else {
            session = s
            lockdown.engage()
        }
    }

    /// Called every half second while locked.
    func tick() {
        if let s = session, s.isOver, openedBy == nil { end() }
    }

    func openUnwind() {
        guard session != nil else { return }
        withAnimation(.smooth(duration: 0.4)) { unwinding = true }
    }

    func closeUnwind() {
        withAnimation(.smooth(duration: 0.4)) { unwinding = false }
    }

    // MARK: - The ring

    /// Another device changed the shared lock or the members.
    private func remote(_ doc: RingDoc) {
        syncLoginItem()
        if hub.inRing {
            hub.startPolling(every: 60)
            Task { await Cloud.setUp() }
        }
        let mine = Session.current
        if let s = doc.session, !s.isOver {
            guard mine != s else { return }
            lock(s, by: doc.member(doc.sessionBy))
        } else if let mine, doc.session == nil, doc.sessionChanged > mine.start, openedBy == nil {
            // Unwound somewhere else: say so for a moment, then open.
            withAnimation(.smooth(duration: 0.4)) {
                openedBy = doc.member(doc.sessionBy) ?? Device(id: UUID(), name: "another device", kind: .phone)
                unwinding = false
            }
            Task {
                try? await Task.sleep(for: .seconds(2.8))
                end()
            }
        }
    }

    /// In a ring the Mac has to be running to be locked, so it starts at login.
    /// Outside a ring it only does while a lock runs (see Lockdown).
    func syncLoginItem() {
        if hub.inRing || session != nil {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
