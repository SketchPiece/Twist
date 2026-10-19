import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The system screen shown over a blocked app. iOS only lets us set an icon,
/// texts, colours and two button labels.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { make() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // An app from a category on the allowlist: remember it and lift the shield.
        // If the store can't be changed from here, the Open button does it.
        guard Session.current != nil, Allowlist.learn(application.token, in: category.token) else { return make() }
        Allowlist.shield(ManagedSettingsStore(named: .init(Shared.storeName)))
        return make(open: true)
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { make() }

    private func make(open: Bool = false) -> ShieldConfiguration {
        // On iOS 26 the shield sits on the system's glass, which follows the phone's
        // light or dark appearance and ignores our background, so the text does too.
        let paper = UIColor(red: 0xEF / 255, green: 0xED / 255, blue: 0xE7 / 255, alpha: 1)
        let graphite = UIColor(red: 0x1B / 255, green: 0x1B / 255, blue: 0x1A / 255, alpha: 1)
        let night = UIColor(red: 0x12 / 255, green: 0x12 / 255, blue: 0x11 / 255, alpha: 1)
        let dark = UITraitCollection.current.userInterfaceStyle == .dark
        let ink = dark ? paper : graphite
        if open {
            return ShieldConfiguration(
                backgroundBlurStyle: nil,
                backgroundColor: dark ? night : paper,
                icon: UIImage(named: "ShieldIcon"),
                title: .init(text: "This one stays open", color: ink),
                subtitle: .init(text: "Its category is on your list.", color: ink.withAlphaComponent(0.6)),
                primaryButtonLabel: .init(text: "Open", color: dark ? graphite : paper),
                primaryButtonBackgroundColor: ink
            )
        }
        let subtitle = Session.current.map { "Opens in \(TimeText.spoken($0.remaining))" } ?? "Opens soon"
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: dark ? night : paper,
            icon: UIImage(named: "ShieldIcon"),
            title: .init(text: "Locked by Twist", color: ink),
            subtitle: .init(text: subtitle, color: ink.withAlphaComponent(0.6)),
            primaryButtonLabel: .init(text: "OK", color: dark ? graphite : paper),
            primaryButtonBackgroundColor: ink,
            secondaryButtonLabel: .init(text: "I need access", color: ink.withAlphaComponent(0.7))
        )
    }
}
