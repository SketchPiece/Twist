import DeviceActivity
import ManagedSettings
import UserNotifications

/// Ends the lockdown when the scheduled interval runs out, even if the app was killed.
final class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == Shared.activityName else { return }
        ManagedSettingsStore(named: .init(Shared.storeName)).clearAllSettings()
        let wasRunning = Session.current != nil
        Session.current = nil
        guard wasRunning else { return }

        let content = UNMutableNotificationContent()
        content.title = "Unlocked"
        content.body = "Your time is up. Open Twist to switch the internet back on."
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "twist.ended", content: content, trigger: nil)
        )
    }
}
