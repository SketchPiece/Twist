import Observation
import SwiftUI

@MainActor @Observable
final class MacModel {
    static let shared = MacModel()

    private(set) var session: Session? = Session.current
    var unwinding = false

    @ObservationIgnored private lazy var lockdown = Lockdown(model: self)

    // MARK: - Session

    func start(minutes: Int) {
        start(seconds: TimeInterval(minutes * 60))
    }

    func start(seconds: TimeInterval) {
        let now = Date()
        let s = Session(start: now, end: now.addingTimeInterval(seconds))
        Session.current = s
        session = s
        unwinding = false
        lockdown.engage()
    }

    func end() {
        Session.current = nil
        session = nil
        unwinding = false
        lockdown.release()
    }

    /// On launch (including after a restart): a running session locks the Mac again.
    func resume() {
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
        if let s = session, s.isOver { end() }
    }

    func openUnwind() {
        guard session != nil else { return }
        withAnimation(.smooth(duration: 0.4)) { unwinding = true }
    }

    func closeUnwind() {
        withAnimation(.smooth(duration: 0.4)) { unwinding = false }
    }
}
