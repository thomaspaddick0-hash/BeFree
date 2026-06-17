import SwiftUI

@main
struct BeFreeApp: App {
    @StateObject private var blockManager = BlockManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blockManager)
                .onOpenURL { url in
                    guard url.scheme == "befree", url.host == "unlock" else { return }
                    blockManager.pendingUnlockDeepLink = true
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { blockManager.checkPendingUnlockFlag() }
                }
        }
    }
}
