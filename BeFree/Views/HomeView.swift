import SwiftUI

struct HomeView: View {
    @EnvironmentObject var blockManager: BlockManager
    @State private var showingBlockCreation = false
    @State private var deepLinkUnlockBlock: Block?

    var body: some View {
        VStack(spacing: 0) {
            if blockManager.activeBlocks.isEmpty {
                Spacer()
                addButton
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(blockManager.activeBlocks) { block in
                            FreeFromCard(block: block)
                        }
                    }
                    .padding()
                    .padding(.bottom, 8)
                }

                Divider()

                addButton
                    .padding(.vertical, 28)
            }
        }
        .navigationTitle("BeFree")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingBlockCreation) {
            BlockCreationView()
        }
        .sheet(item: $deepLinkUnlockBlock) { block in
            UnlockView(block: block)
        }
        .onChange(of: blockManager.pendingUnlockDeepLink) { triggered in
            guard triggered, let block = blockManager.activeBlocks.first else { return }
            deepLinkUnlockBlock = block
            blockManager.pendingUnlockDeepLink = false
        }
    }

    private var addButton: some View {
        VStack(spacing: 14) {
            Button {
                showingBlockCreation = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(Color.green)
                    .clipShape(Circle())
                    .shadow(color: .green.opacity(0.35), radius: 20, x: 0, y: 8)
            }
            Text("Block an app")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Free From Card

struct FreeFromCard: View {
    let block: Block
    @State private var elapsed: TimeInterval = 0
    @State private var showingUnlock = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You have been free from")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(block.appName)
                        .font(.title.bold())
                }
                Spacer()
                Button {
                    showingUnlock = true
                } label: {
                    Image(systemName: "lock.open")
                        .font(.subheadline)
                        .padding(8)
                        .background(.quaternary)
                        .clipShape(Circle())
                }
                .foregroundStyle(.secondary)
            }

            Divider()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("for:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Block.elapsedString(from: elapsed))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .onReceive(timer) { _ in elapsed = block.elapsed }
        .onAppear { elapsed = block.elapsed }
        .sheet(isPresented: $showingUnlock) {
            UnlockView(block: block)
        }
    }
}

// MARK: - Previews

#Preview("With blocks") {
    let manager = BlockManager()
    manager.activeBlocks = [
        Block(id: UUID(), appName: "Instagram", blockedDomains: ["instagram.com"], friendEmail: "friend@example.com", blockedAt: Date().addingTimeInterval(-5025)),
        Block(id: UUID(), appName: "TikTok", blockedDomains: ["tiktok.com"], friendEmail: "friend@example.com", blockedAt: Date().addingTimeInterval(-900))
    ]
    return NavigationStack { HomeView() }.environmentObject(manager)
}

#Preview("Empty") {
    NavigationStack { HomeView() }.environmentObject(BlockManager())
}
