import Foundation

/// State shared between the app and its extensions through the app group.
enum Shared {
    static let appGroup = "group.com.sketchpiece.twist"
    static let storeName = "twist"
    static let activityName = "twist.session"
    static let tunnelBundleID = "com.sketchpiece.twist.tunnel"
    /// Notification sent from the shield; tapping it opens the unwind screen.
    static let unwindCategory = "twist.unwind"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }
}

/// The running lockdown, if any. Written by the app, read by every extension.
struct Session: Codable, Equatable {
    var start: Date
    var end: Date

    var remaining: TimeInterval { max(0, end.timeIntervalSinceNow) }
    var isOver: Bool { Date() >= end }

    private static let key = "session"

    static var current: Session? {
        get {
            guard let data = Shared.defaults.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(Session.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                Shared.defaults.set(data, forKey: key)
            } else {
                Shared.defaults.removeObject(forKey: key)
            }
        }
    }
}

enum TimeText {
    /// "1 h 12 min", "38 min", "less than a minute"
    static func spoken(_ t: TimeInterval) -> String {
        let m = Int((t / 60).rounded(.up))
        if m < 1 { return "less than a minute" }
        let h = m / 60, mm = m % 60
        if h == 0 { return "\(mm) min" }
        return mm == 0 ? "\(h) h" : "\(h) h \(mm) min"
    }

    /// "1:12:08" or "12:08"
    static func clock(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        let h = s / 3600, m = (s % 3600) / 60, ss = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, ss) : String(format: "%d:%02d", m, ss)
    }

    /// Dial setting: "1:30", "0:45"
    static func setting(minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    static func time(_ d: Date) -> String {
        d.formatted(date: .omitted, time: .shortened)
    }
}
