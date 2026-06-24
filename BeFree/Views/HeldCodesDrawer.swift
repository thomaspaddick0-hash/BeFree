import SwiftUI

/// The list of codes the current user is holding for friends. Rendered as a
/// section inside the account/menu drawer.
struct HeldCodesList: View {
    @EnvironmentObject var blockManager: BlockManager

    var body: some View {
        if blockManager.heldBlocks.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(blockManager.heldBlocks) { held in
                        HeldBlockCard(held: held)
                    }
                }
                .padding(16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No codes yet")
                .font(.subheadline.weight(.medium))
            Text("When a friend blocks themselves and names you as their code-holder, it'll appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - Individual code card

private struct HeldBlockCard: View {
    let held: HeldBlock
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Who + what
            VStack(alignment: .leading, spacing: 2) {
                Text(held.blockerName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(held.appName)
                    .font(.title3.bold())
            }

            Divider()

            // The code — big and prominent
            VStack(alignment: .leading, spacing: 4) {
                Text("Their code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)

                HStack(spacing: 8) {
                    ForEach(Array(held.code), id: \.self) { digit in
                        Text(String(digit))
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .frame(width: 44, height: 52)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                }
            }

            // Time elapsed
            Text("Blocked \(elapsedLabel) ago")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onAppear { elapsed = held.elapsed }
        .onReceive(timer) { _ in elapsed = held.elapsed }
    }

    private var elapsedLabel: String {
        let minutes = Int(elapsed) / 60
        let hours   = minutes / 60
        let days    = hours / 24
        if days > 0    { return "\(days)d" }
        if hours > 0   { return "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        return "just now"
    }
}

#Preview {
    let manager = BlockManager()
    manager.heldBlocks = [
        HeldBlock(id: UUID(), blockerName: "Thomas", appName: "Instagram",
                  code: "4729", blockedAt: Date().addingTimeInterval(-7200)),
        HeldBlock(id: UUID(), blockerName: "Emma", appName: "TikTok",
                  code: "1083", blockedAt: Date().addingTimeInterval(-172800)),
    ]
    return HeldCodesList()
        .environmentObject(manager)
}
