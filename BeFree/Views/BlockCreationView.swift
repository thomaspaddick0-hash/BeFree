import SwiftUI
import FamilyControls

/// Category groupings used as a visual stand-in for Apple's FamilyActivityPicker
/// in the simulator (the real picker only renders on a physical device with
/// Screen Time authorization). On device these rows are replaced by the live picker.
private struct BlockCategory: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
}

private let blockCategories: [BlockCategory] = [
    BlockCategory(title: "All Apps & Categories", systemImage: "square.stack.3d.up.fill",         tint: .blue),
    BlockCategory(title: "Social",                systemImage: "bubble.left.and.bubble.right.fill", tint: .pink),
    BlockCategory(title: "Games",                 systemImage: "gamecontroller.fill",             tint: .indigo),
    BlockCategory(title: "Entertainment",         systemImage: "popcorn.fill",                    tint: .orange),
    BlockCategory(title: "Music",                 systemImage: "music.note",                      tint: .purple),
    BlockCategory(title: "Shopping",              systemImage: "cart.fill",                       tint: .green),
    BlockCategory(title: "News",                  systemImage: "newspaper.fill",                  tint: .red),
    BlockCategory(title: "Dating",                systemImage: "heart.fill",                      tint: .pink),
]

struct BlockCreationView: View {
    @EnvironmentObject var blockManager: BlockManager
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .choose
    @State private var familySelection = FamilyActivitySelection()
    @State private var authError: String?

    @State private var mockSelection: BlockCategory?   // simulator-only stand-in selection

    enum Step { case choose, email }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .choose: chooseStep
                case .email:  emailStep
                }
            }
            .animation(.easeInOut, value: step)
        }
    }

    // MARK: - Step 1: Choose app (styled header + inline Apple picker)

    private var chooseStep: some View {
        VStack(spacing: 0) {
            header

            Text("Use the search bar below to find the app you want to block.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 4)

            pickerArea

            continueBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Permission Required", isPresented: .constant(authError != nil), actions: {
            Button("Open Settings") {
                authError = nil
                openScreenTimeSettings()
            }
            Button("Cancel", role: .cancel) { authError = nil }
        }, message: {
            if ProcessInfo.processInfo.isiOSAppOnMac {
                Text("1. Click OK to open System Settings.\n2. Go to Screen Time.\n3. Find BeFree in the app list and enable it.")
            } else {
                Text("Tap 'Open Settings', then go to Screen Time → BeFree to grant access.")
            }
        })
        .onAppear { requestAuthIfNeeded() }
        .sheet(isPresented: $showingAppConfirm) {
            appConfirmSheet
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Choose an app")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
            Text("to block")
                .font(.largeTitle.bold())
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: Picker area — real picker on device, styled stand-in in the simulator

    @ViewBuilder
    private var pickerArea: some View {
        #if targetEnvironment(simulator)
        ScrollView {
            VStack(spacing: 8) {
                mockPicker
                Text("Simulator preview — Apple's real app picker appears here on a physical device.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        #else
        FamilyActivityPicker(selection: $familySelection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 8)
        #endif
    }

    private var mockPicker: some View {
        VStack(spacing: 0) {
            ForEach(Array(blockCategories.enumerated()), id: \.element.id) { index, category in
                Button {
                    mockSelection = category
                } label: {
                    mockRow(category)
                }
                .buttonStyle(.plain)

                if index < blockCategories.count - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .cardBackground()
    }

    private func mockRow(_ category: BlockCategory) -> some View {
        let isSelected = mockSelection?.id == category.id
        return HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? Color.green : Color(.systemGray3))
            iconTile(category.systemImage, tint: category.tint)
            Text(category.title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.systemGray3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func iconTile(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(tint.gradient))
    }

    // MARK: Continue bar

    private var continueBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                showingAppConfirm = true
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!hasSelection)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    private var hasSelection: Bool {
        #if targetEnvironment(simulator)
        return mockSelection != nil
        #else
        return !familySelection.applicationTokens.isEmpty
            || !familySelection.categoryTokens.isEmpty
        #endif
    }

    // MARK: - Step 2: Friend's Email + Confirm modal

    @State private var friendEmail = ""
    @State private var confirmedEntry: AppEntry?
    @State private var showingAppConfirm = false
    @State private var showingConfirm = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var emailStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("Who's holding\nyour code?")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("Enter a trusted friend's email. They'll receive the 4-digit code that unlocks \(resolvedName).")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                TextField("friend@example.com", text: $friendEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding(16)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showingConfirm = true
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!isValidEmail)
                .padding(.horizontal)

                Button("Go back") { step = .choose }
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Friend's email")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingConfirm) {
            if #available(iOS 16.4, *) {
                confirmSheet
                    .presentationDetents([.fraction(0.52)])
                    .presentationCornerRadius(28)
                    .presentationDragIndicator(.visible)
            } else {
                confirmSheet
                    .presentationDetents([.fraction(0.52)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Post-pick confirmation (identify the app for domain blocking)

    private var appConfirmSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    #if !targetEnvironment(simulator)
                    ForEach(Array(familySelection.applicationTokens), id: \.self) { token in
                        Label(token)
                            .font(.title3.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    #endif

                    Text("Which app did you pick?")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("Tap the matching app so we can block its website too. The app itself is already shielded by Screen Time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)
                .padding(.bottom, 8)

                List {
                    ForEach(sortedApps) { entry in
                        Button { confirmedEntry = entry } label: {
                            HStack(spacing: 14) {
                                let icon = appIcon(for: entry.category)
                                iconTile(icon.0, tint: icon.1)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(entry.domains.first ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if confirmedEntry?.id == entry.id {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(.green)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)

                Button {
                    showingAppConfirm = false
                    step = .email
                } label: {
                    Text(confirmedEntry == nil ? "Select the app above" : "Confirm \(confirmedEntry!.name)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(confirmedEntry == nil)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .navigationTitle("Confirm app")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { showingAppConfirm = false }
                }
            }
        }
    }

    private var sortedApps: [AppEntry] {
        AppDomainMap.all.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func appIcon(for category: String) -> (String, Color) {
        switch category {
        case "Social":   return ("bubble.left.and.bubble.right.fill", .pink)
        case "Video":    return ("popcorn.fill", .orange)
        case "Music":    return ("music.note", .purple)
        case "Shopping": return ("cart.fill", .green)
        case "Gaming":   return ("gamecontroller.fill", .indigo)
        case "News":     return ("newspaper.fill", .red)
        case "Dating":   return ("heart.fill", .pink)
        default:         return ("app.fill", .gray)
        }
    }

    private var resolvedName: String {
        confirmedEntry?.name ?? "this app"
    }

    private var resolvedDomains: [String] {
        confirmedEntry?.domains ?? []
    }

    // MARK: - Confirm modal sheet

    private var confirmSheet: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)

                Text("Block \(resolvedName)?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                #if !targetEnvironment(simulator)
                ForEach(Array(familySelection.applicationTokens), id: \.self) { token in
                    Label(token)
                        .font(.headline)
                        .labelStyle(.titleAndIcon)
                }
                #endif

                Text("\(friendEmail) will receive the unlock code.\nYou won't be able to access \(resolvedName) — app or website — until they share it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 10) {
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Confirm")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSubmitting)
                .padding(.horizontal)

                Button("Cancel") {
                    showingConfirm = false
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    private func requestAuthIfNeeded() {
        #if !targetEnvironment(simulator)
        guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }
        Task {
            switch AuthorizationCenter.shared.authorizationStatus {
            case .approved, .approvedWithDataAccess:
                break
            case .notDetermined:
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                } catch {
                    authError = "denied"
                }
            case .denied:
                authError = "denied"
            @unknown default:
                authError = "denied"
            }
        }
        #endif
    }

    private func openScreenTimeSettings() {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            // Running as "Designed for iPhone" on Mac.
            // UIApplication.openSettingsURLString produces the "Touch Alternatives" window,
            // so we try x-apple.systempreferences URLs instead — these open System Settings.
            let candidates = [
                "x-apple.systempreferences:com.apple.Screen-Time-Settings.extension",
                "x-apple.systempreferences:com.apple.preference.screentime",
                "x-apple.systempreferences:"
            ]
            func tryNext(_ index: Int) {
                guard index < candidates.count,
                      let url = URL(string: candidates[index]) else { return }
                UIApplication.shared.open(url) { success in
                    if !success { tryNext(index + 1) }
                }
            }
            tryNext(0)
        } else {
            // On real iPhone, try App-Prefs:SCREEN_TIME; fall back to app settings.
            guard let url = URL(string: "App-Prefs:SCREEN_TIME") else { return }
            UIApplication.shared.open(url) { success in
                if !success, let fallback = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(fallback)
                }
            }
        }
    }

    private var isValidEmail: Bool {
        let t = friendEmail.trimmingCharacters(in: .whitespaces)
        return t.contains("@") && t.contains(".")
    }

    private func submit() async {
        // The selected app identifies the domains to filter (web block); Apple's
        // token shields the native app. In-app screens prefer the token's real
        // name + icon, falling back to this stored name (e.g. in the simulator).
        let name = resolvedName
        let domains = resolvedDomains
        isSubmitting = true
        errorMessage = nil
        do {
            #if targetEnvironment(simulator)
            try await blockManager.addBlock(
                appName: name,
                domains: domains,
                friendEmail: friendEmail.trimmingCharacters(in: .whitespaces),
                userName: ""
            )
            #else
            try await blockManager.addBlock(
                appName: name,
                selection: familySelection.applicationTokens.isEmpty ? nil : familySelection,
                domains: domains,
                friendEmail: friendEmail.trimmingCharacters(in: .whitespaces),
                userName: ""
            )
            #endif
            showingConfirm = false
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

private extension View {
    /// White rounded card with a hairline border and soft shadow, matching the list panel.
    func cardBackground() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

#Preview {
    BlockCreationView()
        .environmentObject(BlockManager())
}
