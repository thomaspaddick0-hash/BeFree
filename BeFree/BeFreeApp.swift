import SwiftUI
import FamilyControls

@main
struct BeFreeApp: App {
    @StateObject private var blockManager = BlockManager()

    init() {
        Task { await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blockManager)
        }
    }
}
