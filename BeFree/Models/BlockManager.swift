import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class BlockManager: ObservableObject {
    @Published var activeBlocks: [Block] = []
    @Published var pendingUnlockDeepLink = false

    // Lazy so the XPC connection isn't attempted until first use.
    // All access sites are guarded with #if !targetEnvironment(simulator)
    // because these services are unavailable in the simulator.
    #if !targetEnvironment(simulator)
    private lazy var store = ManagedSettingsStore()
    private lazy var activityCenter = DeviceActivityCenter()
    private let activityName = DeviceActivityName("befreeRestrictions")
    #endif

    private let supabase = SupabaseService.shared
    private let resend = ResendService.shared
    private let sharedDefaults = UserDefaults(suiteName: "group.com.befree.app")!

    func loadBlocks() async {
        do { try await supabase.signInIfNeeded() } catch { return }
        guard let blocks = try? await supabase.fetchActiveBlocks() else { return }
        activeBlocks = blocks
    }

    func addBlock(
        appName: String,
        domains: [String],
        friendEmail: String,
        selection: FamilyActivitySelection? = nil
    ) async throws {
        let code = String(format: "%04d", Int.random(in: 0...9999))
        let now = Date()
        let selectionData = selection.flatMap { try? JSONEncoder().encode($0) }

        let block = Block(
            id: UUID(),
            appName: appName,
            blockedDomains: domains,
            friendEmail: friendEmail,
            blockedAt: now,
            activitySelectionData: selectionData
        )

        guard let userID = supabase.currentUserID else { throw BeFreeError.notSignedIn }
        try await supabase.insertBlock(block, code: code, userID: userID)
        try await resend.sendCode(code, appName: appName, toEmail: friendEmail)

        #if !targetEnvironment(simulator)
        if let selection { applyRestrictions(selection: selection, domains: domains) }
        else { applyDomainsOnly(domains: domains) }
        #endif

        var stored = storedBlocks()
        stored[block.id.uuidString] = now
        sharedDefaults.set(try? JSONEncoder().encode(stored), forKey: "blockedAt")

        activeBlocks.append(block)
        saveStoredSelections()

        #if !targetEnvironment(simulator)
        startMonitoringIfNeeded()
        #endif
    }

    func unlock(block: Block, code: String) async throws {
        try await supabase.verifyAndUnlock(blockId: block.id, code: code)

        #if !targetEnvironment(simulator)
        if let data = block.activitySelectionData,
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            store.shield.applications?.subtract(selection.applicationTokens)
        }
        rebuildWebFilter()
        #endif

        var stored = storedBlocks()
        stored.removeValue(forKey: block.id.uuidString)
        sharedDefaults.set(try? JSONEncoder().encode(stored), forKey: "blockedAt")

        activeBlocks.removeAll { $0.id == block.id }
        saveStoredSelections()

        #if !targetEnvironment(simulator)
        if activeBlocks.isEmpty {
            activityCenter.stopMonitoring([activityName])
        }
        #endif
    }

    // MARK: - Private

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

    #if !targetEnvironment(simulator)
    private func applyRestrictions(selection: FamilyActivitySelection, domains: [String]) {
        var blocked = store.shield.applications ?? []
        blocked.formUnion(selection.applicationTokens)
        store.shield.applications = blocked
        rebuildWebFilter()
    }

    private func applyDomainsOnly(domains: [String]) {
        rebuildWebFilter()
    }

    private func rebuildWebFilter() {
        let allDomains = activeBlocks.filter(\.isActive).flatMap(\.blockedDomains)
        store.webContent.blockedByFilter = allDomains.isEmpty
            ? nil
            : .specific(Set(allDomains.map { WebDomain(domain: $0) }))
    }

    private func startMonitoringIfNeeded() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try? activityCenter.startMonitoring(activityName, during: schedule)
    }
    #endif

    private func storedBlocks() -> [String: Date] {
        guard let data = sharedDefaults.data(forKey: "blockedAt"),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return [:] }
        return decoded
    }
}

private struct StoredSelection: Codable {
    let blockId: String
    let selectionData: Data?
    let domains: [String]
}
