import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class BlockManager: ObservableObject {
    @Published var activeBlocks: [Block] = []
    @Published var heldBlocks: [HeldBlock] = []
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
    private let sharedDefaults = UserDefaults(suiteName: "group.com.timetobefree.app")!

    // A block being assembled across the creation flow. Restrictions are applied
    // to ManagedSettingsStore immediately (for instant effect) but the durable
    // Supabase record + accountability email are only created on finalize. If the
    // user backs out before finishing, `cancelPendingBlock()` rolls everything back.
    private var pendingSelection: FamilyActivitySelection?
    private var pendingDomains: [String] = []

    func loadBlocks() async {
        do { try await supabase.signInIfNeeded() } catch { return }
        async let mine = supabase.fetchActiveBlocks()
        async let held = supabase.fetchBlocksImHolding()
        activeBlocks = (try? await mine) ?? []
        heldBlocks   = (try? await held) ?? []
    }

    /// The shield's "Enter unlock code" button can't open us directly (no public
    /// API), so it leaves a flag in the shared app group. Pick it up whenever the
    /// app comes to the foreground and route to the unlock screen.
    func checkPendingUnlockFlag() {
        guard sharedDefaults.bool(forKey: "pendingUnlock") else { return }
        sharedDefaults.set(false, forKey: "pendingUnlock")
        pendingUnlockDeepLink = true
    }

    // MARK: - Creation flow

    /// Reset any half-applied state when a new creation flow starts.
    func beginPendingBlock() {
        pendingSelection = nil
        pendingDomains = []
    }

    /// Screen 2: shield the picked app immediately.
    func applyPendingAppShield(_ selection: FamilyActivitySelection) {
        pendingSelection = selection
        #if !targetEnvironment(simulator)
        rebuildShield()
        #endif
    }

    /// Screen 3: filter the picked app's website immediately.
    func applyPendingWebDomains(_ domains: [String]) {
        pendingDomains = domains
        #if !targetEnvironment(simulator)
        rebuildWebFilter()
        #endif
    }

    /// User abandoned the flow before finishing — undo anything applied.
    func cancelPendingBlock() {
        pendingSelection = nil
        pendingDomains = []
        #if !targetEnvironment(simulator)
        rebuildShield()
        rebuildWebFilter()
        #endif
    }

    /// Screen 4: persist the block, email the friend, and keep restrictions in place.
    func finalizePendingBlock(appName: String, friendEmail: String, userName: String) async throws {
        try await supabase.signInIfNeeded()

        let displayName = supabase.currentUserDisplayName
        let selection = pendingSelection
        let domains = pendingDomains
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
        try await resend.sendCode(code, appName: appName, toEmail: friendEmail, userName: displayName)

        var stored = storedBlocks()
        stored[block.id.uuidString] = now
        sharedDefaults.set(try? JSONEncoder().encode(stored), forKey: "blockedAt")

        activeBlocks.append(block)
        pendingSelection = nil
        pendingDomains = []
        saveStoredSelections()

        #if !targetEnvironment(simulator)
        rebuildShield()
        rebuildWebFilter()
        startMonitoringIfNeeded()
        #endif
    }

    // MARK: - Unlock

    func unlock(block: Block, code: String) async throws {
        try await supabase.signInIfNeeded()
        try await supabase.verifyAndUnlock(blockId: block.id, code: code)

        var stored = storedBlocks()
        stored.removeValue(forKey: block.id.uuidString)
        sharedDefaults.set(try? JSONEncoder().encode(stored), forKey: "blockedAt")

        activeBlocks.removeAll { $0.id == block.id }
        saveStoredSelections()

        #if !targetEnvironment(simulator)
        rebuildShield()
        rebuildWebFilter()
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
    /// Rebuild the app shield from every active block plus the pending one, so
    /// rollback and unlock both reduce to "rebuild from current truth".
    private func rebuildShield() {
        var tokens = Set<ApplicationToken>()
        for block in activeBlocks where block.isActive {
            if let data = block.activitySelectionData,
               let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
                tokens.formUnion(selection.applicationTokens)
            }
        }
        if let pendingSelection {
            tokens.formUnion(pendingSelection.applicationTokens)
        }
        store.shield.applications = tokens.isEmpty ? nil : tokens
    }

    private func rebuildWebFilter() {
        var allDomains = activeBlocks.filter(\.isActive).flatMap(\.blockedDomains)
        allDomains.append(contentsOf: pendingDomains)
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
