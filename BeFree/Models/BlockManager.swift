import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class BlockManager: ObservableObject {
    @Published var activeBlocks: [Block] = []
    @Published var pendingUnlockDeepLink = false

    private let store = ManagedSettingsStore()
    private let activityCenter = DeviceActivityCenter()
    private let supabase = SupabaseService.shared
    private let resend = ResendService.shared

    // Shared App Group UserDefaults — also read by the Shield extension
    private let sharedDefaults = UserDefaults(suiteName: "group.com.befree.app")!

    func loadBlocks() async {
        do { try await supabase.signInIfNeeded() } catch { return }
        guard let blocks = try? await supabase.fetchActiveBlocks() else { return }
        activeBlocks = blocks
    }

    func addBlock(
        appName: String,
        selection: FamilyActivitySelection,
        domains: [String],
        friendEmail: String,
        userName: String
    ) async throws {
        let code = String(format: "%04d", Int.random(in: 0...9999))
        let now = Date()

        // Persist selection data for re-applying on relaunch
        let selectionData = try JSONEncoder().encode(selection)

        let block = Block(
            id: UUID(),
            appName: appName,
            blockedDomains: domains,
            friendEmail: friendEmail,
            blockedAt: now,
            activitySelectionData: selectionData
        )

        // Save to Supabase (stores hashed code)
        guard let userID = supabase.currentUserID else { throw BeFreeError.notSignedIn }
        try await supabase.insertBlock(block, code: code, userID: userID)

        // Email the code to the friend
        try await resend.sendCode(code, appName: appName, userName: userName, toEmail: friendEmail)

        // Apply restrictions
        applyRestrictions(selection: selection, domains: domains)

        // Persist block timestamp for Shield extension stopwatch
        var stored = storedBlocks()
        stored[block.id.uuidString] = now
        sharedDefaults.set(
            try? JSONEncoder().encode(stored),
            forKey: "blockedAt"
        )

        activeBlocks.append(block)
        saveStoredSelections()
        startMonitoringIfNeeded()
    }

    func unlock(block: Block, code: String) async throws {
        try await supabase.verifyAndUnlock(blockId: block.id, code: code)

        // Only remove restrictions for this specific block's apps
        if let data = block.activitySelectionData,
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            store.application.blockedApplications?.subtract(selection.applicationTokens)
        }
        // Rebuild web filter from remaining active blocks
        rebuildWebFilter()

        var stored = storedBlocks()
        stored.removeValue(forKey: block.id.uuidString)
        sharedDefaults.set(try? JSONEncoder().encode(stored), forKey: "blockedAt")

        activeBlocks.removeAll { $0.id == block.id }
        saveStoredSelections()
        if activeBlocks.isEmpty {
            activityCenter.stopMonitoring([activityName])
        }
    }

    // MARK: - Private

    private let activityName = DeviceActivityName("befreeRestrictions")

    private func saveStoredSelections() {
        let selections = activeBlocks.map { block in
            StoredSelection(
                blockId: block.id.uuidString,
                selectionData: block.activitySelectionData,
                domains: block.blockedDomains
            )
        }
        sharedDefaults.set(try? JSONEncoder().encode(selections), forKey: "storedSelections")
    }

    private func startMonitoringIfNeeded() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try? activityCenter.startMonitoring(activityName, during: schedule)
    }

    private func applyRestrictions(selection: FamilyActivitySelection, domains: [String]) {
        var blocked = store.application.blockedApplications ?? []
        blocked.formUnion(selection.applicationTokens)
        store.application.blockedApplications = blocked

        rebuildWebFilter()
    }

    private func rebuildWebFilter() {
        let allDomains = activeBlocks.filter(\.isActive).flatMap(\.blockedDomains)
        store.webContent.blockedByFilter = allDomains.isEmpty
            ? nil
            : .specific(WebContentFilter(blockedDomains: Set(allDomains)))
    }

    private func storedBlocks() -> [String: Date] {
        guard let data = sharedDefaults.data(forKey: "blockedAt"),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return [:] }
        return decoded
    }
}

// Shared structure — must match the definition in DeviceActivityMonitorExtension.swift
private struct StoredSelection: Codable {
    let blockId: String
    let selectionData: Data?
    let domains: [String]
}
