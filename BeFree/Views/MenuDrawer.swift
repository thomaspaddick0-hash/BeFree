import SwiftUI

/// Trailing slide-in sidebar opened from the home screen's account button.
/// Root shows a profile summary plus rows that drill into the codes the user is
/// holding and their account (where Sign Out lives).
struct MenuDrawer: View {
    @EnvironmentObject var blockManager: BlockManager
    @ObservedObject private var auth = SupabaseService.shared
    @Binding var isShowing: Bool

    private enum Screen { case menu, heldCodes, account }
    @State private var screen: Screen = .menu

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 0) {
                header
                Divider()
                content
            }
            .frame(width: min(UIScreen.main.bounds.width * 0.82, 340))
            .frame(maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.18), radius: 24, x: -4, y: 0)
            .padding(.vertical, 20)
            .padding(.trailing, 12)
        }
    }

    // MARK: - Header (back chevron in sub-screens, close always)

    private var header: some View {
        HStack(spacing: 12) {
            if screen != .menu {
                Button { goTo(.menu) } label: {
                    Image(systemName: "chevron.left").font(.headline)
                }
                .foregroundStyle(.primary)
            }
            Text(headerTitle).font(.title3.bold())
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

    private var headerTitle: String {
        switch screen {
        case .menu:      return "Menu"
        case .heldCodes: return "Codes I'm Holding"
        case .account:   return "Account"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .menu:      menuRoot
        case .heldCodes: HeldCodesList()
        case .account:   AccountView()
        }
    }

    // MARK: - Menu root

    private var menuRoot: some View {
        VStack(spacing: 16) {
            profileSummary

            VStack(spacing: 10) {
                menuRow(icon: "key.fill", tint: .green,
                        title: "Codes I'm Holding",
                        badge: blockManager.heldBlocks.count) { goTo(.heldCodes) }

                menuRow(icon: "person.crop.circle.fill", tint: .blue,
                        title: "Account",
                        badge: 0) { goTo(.account) }
            }

            Spacer()
        }
        .padding(20)
    }

    private var profileSummary: some View {
        HStack(spacing: 12) {
            InitialsCircle(initials: auth.currentUserInitials, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(auth.currentUserDisplayName)
                    .font(.headline)
                if let email = auth.currentUserEmail {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    private func menuRow(icon: String, tint: Color, title: String,
                         badge: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8).fill(tint.gradient))
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green))
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private func goTo(_ target: Screen) {
        withAnimation(.easeInOut(duration: 0.2)) { screen = target }
    }

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isShowing = false
        }
    }
}

// MARK: - Account screen

private struct AccountView: View {
    @ObservedObject private var auth = SupabaseService.shared
    @State private var isSigningOut = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                InitialsCircle(initials: auth.currentUserInitials, size: 72)
                VStack(spacing: 4) {
                    Text(auth.currentUserDisplayName)
                        .font(.title3.bold())
                    if let email = auth.currentUserEmail {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !auth.currentUserProvider.isEmpty {
                        Text("Signed in with \(auth.currentUserProvider)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.top, 16)

            Spacer()

            Button {
                isSigningOut = true
                Task { try? await SupabaseService.shared.signOut() }
            } label: {
                Group {
                    if isSigningOut {
                        ProgressView().tint(.white)
                    } else {
                        Text("Sign Out").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isSigningOut)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Initials avatar

struct InitialsCircle: View {
    let initials: String
    var size: CGFloat = 32

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.green.gradient))
    }
}

#Preview {
    let manager = BlockManager()
    manager.heldBlocks = [
        HeldBlock(id: UUID(), blockerName: "Emma", appName: "TikTok",
                  code: "1083", blockedAt: Date().addingTimeInterval(-172800)),
    ]
    return ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        MenuDrawer(isShowing: .constant(true))
            .environmentObject(manager)
    }
}
