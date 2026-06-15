import SwiftUI

struct BlockRowView: View {
    let block: Block
    @State private var elapsed: TimeInterval = 0
    @State private var showingUnlock = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                BlockAppTitle(block: block)
                    .font(.headline)
                Text(Block.elapsedString(from: elapsed))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Unlock") { showingUnlock = true }
                .buttonStyle(.bordered)
                .tint(.green)
        }
        .padding(.vertical, 4)
        .onReceive(timer) { _ in elapsed = block.elapsed }
        .onAppear { elapsed = block.elapsed }
        .sheet(isPresented: $showingUnlock) {
            UnlockView(block: block)
        }
    }
}

#Preview {
    List {
        BlockRowView(block: Block(
            id: UUID(),
            appName: "Instagram",
            blockedDomains: ["instagram.com"],
            friendEmail: "friend@example.com",
            blockedAt: Date().addingTimeInterval(-5025)
        ))
        BlockRowView(block: Block(
            id: UUID(),
            appName: "TikTok",
            blockedDomains: ["tiktok.com"],
            friendEmail: "friend@example.com",
            blockedAt: Date().addingTimeInterval(-900)
        ))
    }
    .environmentObject(BlockManager())
}
