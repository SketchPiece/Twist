import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The system screen shown over a blocked app. iOS only lets us set an icon,
/// texts, colours and two button labels.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { make() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { make() }

    private func make() -> ShieldConfiguration {
        let paper = UIColor(red: 0xEF / 255, green: 0xED / 255, blue: 0xE7 / 255, alpha: 1)
        let graphite = UIColor(red: 0x1B / 255, green: 0x1B / 255, blue: 0x1A / 255, alpha: 1)
        let orange = UIColor(red: 1, green: 0x5A / 255, blue: 0x1F / 255, alpha: 1)
        let subtitle = Session.current.map { "Opens in \(TimeText.spoken($0.remaining))" } ?? "Opens soon"
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: UIColor(red: 0x12 / 255, green: 0x12 / 255, blue: 0x11 / 255, alpha: 1),
            icon: UIImage(named: "ShieldIcon"),
            title: .init(text: "Locked by Twist", color: paper),
            subtitle: .init(text: subtitle, color: paper.withAlphaComponent(0.6)),
            primaryButtonLabel: .init(text: "OK", color: graphite),
            primaryButtonBackgroundColor: orange,
            secondaryButtonLabel: .init(text: "I need access", color: paper)
        )
    }
}
