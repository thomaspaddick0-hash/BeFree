import SwiftUI

struct ContentView: View {
    @EnvironmentObject var blockManager: BlockManager
    @ObservedObject private var auth = SupabaseService.shared

    var body: some View {
        if auth.isSignedIn {
            NavigationStack {
                HomeView()
            }
            .task { await blockManager.loadBlocks() }
        } else {
            OnboardingView()
        }
    }
}
