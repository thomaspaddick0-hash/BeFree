import SwiftUI

struct HomeView: View {
    @EnvironmentObject var blockManager: BlockManager
    @State private var showingAddBlock = false
    @State private var deepLinkUnlockBlock: Block?

    var body: some View {
        Group {
            if blockManager.activeBlocks.isEmpty {
                emptyState
            } else {
                blockList
            }
        }
        .navigationTitle("BeFree")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddBlock = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAddBlock) {
            AddBlockView()
        }
        .sheet(item: $deepLinkUnlockBlock) { block in
            UnlockView(block: block)
        }
        .onChange(of: blockManager.pendingUnlockDeepLink) { _, triggered in
            guard triggered, let block = blockManager.activeBlocks.first else { return }
            deepLinkUnlockBlock = block
            blockManager.pendingUnlockDeepLink = false
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.open")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No active blocks")
                .font(.title2.weight(.semibold))
            Text("Tap + to block an app and send the unlock\ncode to a trusted friend.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Block an App") { showingAddBlock = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    private var blockList: some View {
        List {
            Section {
                ForEach(blockManager.activeBlocks) { block in
                    BlockRowView(block: block)
                }
            } header: {
                Text("Staying clean")
            }
        }
        .listStyle(.insetGrouped)
    }
}

private extension BlockManager {
    static var withBlocks: BlockManager {
        let m = BlockManager()
        m.activeBlocks = [
            Block(id: UUID(), appName: "Instagram", blockedDomains: ["instagram.com"], friendEmail: "friend@example.com", blockedAt: Date().addingTimeInterval(-5025)),
            Block(id: UUID(), appName: "TikTok", blockedDomains: ["tiktok.com"], friendEmail: "friend@example.com", blockedAt: Date().addingTimeInterval(-900))
        ]
        return m
    }
}

#Preview("With blocks") {
    NavigationStack { HomeView() }
        .environmentObject(BlockManager.withBlocks)
}

#Preview("Empty") {
    NavigationStack { HomeView() }
        .environmentObject(BlockManager())
}
