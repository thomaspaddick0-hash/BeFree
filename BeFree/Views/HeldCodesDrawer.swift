import SwiftUI

struct HeldCodesDrawer: View {
    @EnvironmentObject var blockManager: BlockManager
    @Binding var isShowing: Bool

    var body: some View {
        ZStack(alignment: .trailing) {
            // Dimming backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { close() }

            // Drawer panel
            VStack(spacing: 0) {
                drawerHeader
                Divider()
                drawerContent
            }
            .frame(width: min(UIScreen.main.bounds.width * 0.82, 340))
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.18), radius: 24, x: -4, y: 0)
            .padding(.vertical, 20)
            .padding(.trailing, 12)
        }
    }

    private var drawerHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Codes I'm Holding")
                    .font(.title3.bold())
                Text("\(blockManager.heldBlocks.count) active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { close() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var drawerContent: some View {
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

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isShowing = false
        }
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
    return ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        HeldCodesDrawer(isShowing: .constant(true))
            .environmentObject(manager)
    }
}
