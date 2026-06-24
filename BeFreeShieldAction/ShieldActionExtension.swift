import ManagedSettings
import Foundation

// Handles taps on the shield buttons. This MUST be its own extension target
// registered with the `com.apple.ManagedSettings.shield-action-service` point —
// if it shares the configuration extension's target, iOS never calls it and the
// buttons do nothing.
class ShieldActionExtension: ShieldActionDelegate {

    private let sharedDefaults = UserDefaults(suiteName: "group.com.timetobefree.app")

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // There's no public API to launch the parent app from a shield, so we
            // leave a flag the main app picks up when the user next opens BeFree,
            // then dismiss the shield to the Home Screen.
            sharedDefaults?.set(true, forKey: "pendingUnlock")
            completionHandler(.close)
        case .secondaryButtonPressed,
             .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            // "Go back" — send the user back to the Home Screen. The shield
            // doesn't configure a secondary submenu, but the enum cases must
            // still be handled for the switch to be exhaustive.
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
        // The web shield only offers "Go back".
        completionHandler(.close)
    }
}
