import SwiftUI

struct ContentView: View {
    @EnvironmentObject var blockManager: BlockManager

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .task { await blockManager.loadBlocks() }
    }
}
