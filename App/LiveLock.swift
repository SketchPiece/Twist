import ActivityKit
import Foundation

/// The lock's Live Activity: started with a lock, ended with it.
/// Activities can only be started while the app is in front; a lock that arrives in the
/// background gets its activity the next time Twist opens.
enum LiveLock {
    private static var current: [Activity<LockAttributes>] { Activity<LockAttributes>.activities }

    static func show(_ s: Session, by: Device?) async {
        var state = LockAttributes.ContentState(start: s.start, end: s.end, lockedBy: by?.name)
        // After a relaunch the app no longer knows who locked; keep what the activity says.
        if let old = current.first?.content.state, old.end == s.end, state.lockedBy == nil {
            state.lockedBy = old.lockedBy
        }
        // Stale at the end time, so the activity turns to "Open" even if Twist isn't running.
        let content = ActivityContent(state: state, staleDate: s.end)
        if let a = current.first(where: { $0.activityState == .active }) {
            if a.content.state != state { await a.update(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled, !s.isOver else { return }
        do {
            _ = try Activity.request(attributes: LockAttributes(), content: content)
        } catch {
            NSLog("Live Activity failed: %@", "\(error)")
        }
    }

    static func hide() async {
        #if DEBUG
        if previewing { return }
        #endif
        for a in current {
            await a.end(nil, dismissalPolicy: .immediate)
        }
    }

    #if DEBUG
    private static var previewing = false

    /// `-twistLiveActivityPreview`: show the activity for a made-up 1 h 12 min lock,
    /// to look at it in the Simulator without Screen Time.
    static func previewIfAsked() {
        guard ProcessInfo.processInfo.arguments.contains("-twistLiveActivityPreview") else { return }
        previewing = true
        let now = Date()
        Task {
            // Activities can only start once the app is in front.
            try? await Task.sleep(for: .seconds(1))
            await show(Session(start: now, end: now.addingTimeInterval(72 * 60 + 8)), by: nil)
        }
    }
    #endif
}
