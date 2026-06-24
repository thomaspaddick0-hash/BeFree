import ManagedSettings
import ManagedSettingsUI
import UIKit

// This extension customises the system-provided block screen shown when
// the user tries to open a blocked app.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let sharedDefaults = UserDefaults(suiteName: "group.com.timetobefree.app")!

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
                text: elapsed.map { "You've been free for \($0). Keep it going." } ?? "Stay strong.",
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

    // The system renders the shield as a one-off static snapshot — there is no
    // API to drive a live, ticking timer here. So we report elapsed time at
    // minute resolution (a milestone) rather than seconds, which would otherwise
    // look like a frozen stopwatch.
    private func elapsedString(for application: Application) -> String? {
        guard
            let data = sharedDefaults.data(forKey: "blockedAt"),
            let stored = try? JSONDecoder().decode([String: Date].self, from: data),
            let date = stored.values.first
        else { return nil }
        let interval = Date().timeIntervalSince(date)
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m) min" }
        return "under a minute"
    }
}
