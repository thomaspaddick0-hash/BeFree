import ManagedSettings
import ManagedSettingsUI
import UIKit

// This extension customises the system-provided block screen shown when
// the user tries to open a blocked app.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let sharedDefaults = UserDefaults(suiteName: "group.com.befree.app")!

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let appName = application.localizedDisplayName ?? "this app"
        let elapsed = elapsedString(for: application)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemBackground,
            title: ShieldConfiguration.Label(
                text: "You're blocked from \(appName)",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: elapsed.map { "Clean for \($0)" } ?? "Stay strong.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Enter unlock code",
                color: .white
            ),
            primaryButtonBackgroundColor: .systemGreen,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Go back",
                color: .systemBlue
            )
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let domain = webDomain.domain ?? "this site"
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemBackground,
            title: ShieldConfiguration.Label(
                text: "\(domain) is blocked",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "You blocked this site along with an app.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Go back",
                color: .white
            ),
            primaryButtonBackgroundColor: .systemBlue
        )
    }

    // MARK: - Helpers

    private func elapsedString(for application: Application) -> String? {
        guard
            let data = sharedDefaults.data(forKey: "blockedAt"),
            let stored = try? JSONDecoder().decode([String: Date].self, from: data),
            let date = stored.values.first
        else { return nil }
        let interval = Date().timeIntervalSince(date)
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        return h > 0 ? String(format: "%dh %02dm %02ds", h, m, s) : String(format: "%02dm %02ds", m, s)
    }
}
