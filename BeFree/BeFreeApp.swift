import SwiftUI

@main
struct BeFreeApp: App {
    @StateObject private var blockManager = BlockManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blockManager)
        }
    }
}
