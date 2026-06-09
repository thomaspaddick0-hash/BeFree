import SwiftUI

struct ContentView: View {
    @EnvironmentObject var blockManager: BlockManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            NavigationStack {
                HomeView()
            }
            .task { await blockManager.loadBlocks() }
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}
