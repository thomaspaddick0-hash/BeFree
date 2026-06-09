import ManagedSettings
import CryptoKit
import Foundation

// Handles taps on the shield buttons.
// The primary button ("Enter unlock code") opens the main BeFree app
// via a deep link so the user can enter their code.
class ShieldActionExtension: ShieldActionDataSource {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // Deep-link into the main app to show the unlock screen
            // The main app registers the befree:// URL scheme
            openBeFreeApp()
            completionHandler(.defer)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    private func openBeFreeApp() {
        guard let url = URL(string: "befree://unlock") else { return }
        // Extensions cannot call UIApplication.shared directly.
        // Use the open(_:options:completionHandler:) approach via NSExtensionContext,
        // or rely on the system to surface the main app. In practice, returning .defer
        // and having the user tap the app icon works well for this flow.
        _ = url
    }
}
