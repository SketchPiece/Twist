import ManagedSettings
import UserNotifications

/// Shield buttons. The primary button closes the blocked app. The secondary one
/// can't open Twist directly, so it posts a notification that does.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    private func respond(_ action: ShieldAction, _ done: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .secondaryButtonPressed:
            let content = UNMutableNotificationContent()
            content.title = "Need it now?"
            content.body = "Tap, then hold to unwind the timer."
            content.sound = .default
            content.categoryIdentifier = Shared.unwindCategory
            content.userInfo = ["unwind": true]
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "twist.unwind", content: content, trigger: nil)
            ) { _ in done(.close) }
        default:
            done(.close)
        }
    }
}
