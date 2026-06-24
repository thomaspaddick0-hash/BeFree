import SwiftUI

@main
struct BeFreeApp: App {
    @StateObject private var blockManager = BlockManager()
    // Start the auth listener as soon as the app process starts.
    private let supabase = SupabaseService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blockManager)
                .onOpenURL { url in
                    guard url.scheme == "befree" else { return }
                    switch url.host {
                    case "auth-callback":
                        Task { await supabase.handleAuthCallback(url: url) }
                    case "unlock":
                        blockManager.pendingUnlockDeepLink = true
                    default:
                        break
                    }
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { blockManager.checkPendingUnlockFlag() }
                }
        }
    }
}
