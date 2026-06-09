import SwiftUI

struct BlockRowView: View {
    let block: Block
    @State private var elapsed: TimeInterval = 0
    @State private var showingUnlock = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(block.appName)
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
