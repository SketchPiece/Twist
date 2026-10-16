import ActivityKit
import Foundation

/// The Live Activity for a running lock: the countdown on the Lock Screen and in the Dynamic Island.
/// Shared by the app, which starts and ends it, and the Island extension, which draws it.
struct LockAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var start: Date
        var end: Date
        /// The device that started the lock, when it wasn't this iPhone.
        var lockedBy: String?
    }
}

extension LockAttributes.ContentState {
    /// One turn of the dial is 4 hours, so the orange arc is the time left out of 4 h,
    /// the same as the wedge on the dial in the app.
    var dialRange: ClosedRange<Date> { end.addingTimeInterval(-4 * 3600)...end }
    var countdown: ClosedRange<Date> { min(start, end)...end }
}
