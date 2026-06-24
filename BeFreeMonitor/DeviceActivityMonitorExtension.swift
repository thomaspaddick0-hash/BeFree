import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

// This extension runs in a separate process. It is invoked by the system
// when a DeviceActivitySchedule event fires (intervalDidStart / intervalDidEnd)
// or when a DeviceActivityEvent threshold is crossed.
//
// We use it to ensure restrictions are re-applied after a device restart,
// since ManagedSettingsStore state does not persist across reboots automatically
// when set by a user-consent app (as opposed to an MDM profile).
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.timetobefree.app")!

    override func intervalDidStart(for activity: DeviceActivityName) {
        // Called when the daily monitoring schedule starts.
        // Re-apply any restrictions that were active when the device was last on.
        reapplyStoredRestrictions()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        // Could be used in a future version to warn the user they're approaching a limit.
    }

    // MARK: - Private

    private func reapplyStoredRestrictions() {
        guard
            let data = sharedDefaults.data(forKey: "storedSelections"),
            let selections = try? JSONDecoder().decode([StoredSelection].self, from: data)
        else { return }

        var allDomains: Set<String> = []
        for item in selections {
            if let selectionData = item.selectionData,
               let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData) {
                var blocked = store.shield.applications ?? []
                blocked.formUnion(selection.applicationTokens)
                store.shield.applications = blocked
            }
            item.domains.forEach { allDomains.insert($0) }
        }

        if !allDomains.isEmpty {
            store.webContent.blockedByFilter = .specific(
                Set(allDomains.map { WebDomain(domain: $0) })
            )
        }
    }
}

// Minimal Codable wrapper stored in shared App Group defaults
private struct StoredSelection: Codable {
    let blockId: String
    let selectionData: Data?
    let domains: [String]
}
