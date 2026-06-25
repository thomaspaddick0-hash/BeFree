import SwiftUI
import FamilyControls

/// A one-tap suggestion chip for the most common offenders on the
/// "Also block the URL" screen. Tapping toggles its domain into the block list.
private struct URLChip: Identifiable {
    let id = UUID()
    let name: String
    let domain: String
}

private let suggestedChips: [URLChip] = [
    URLChip(name: "Instagram", domain: "instagram.com"),
    URLChip(name: "TikTok",    domain: "tiktok.com"),
    URLChip(name: "Facebook",  domain: "facebook.com"),
]

struct BlockCreationView: View {
    @EnvironmentObject var blockManager: BlockManager
    @Environment(\.dismiss) private var dismiss

    private enum Step: Hashable { case website, email }

    @State private var path: [Step] = []

    @State private var familySelection = FamilyActivitySelection()
    @State private var mockSelected = false            // simulator-only stand-in
    @State private var authError = false

    // Human-readable name for Supabase + emails. Apple doesn't expose the picked app's name.
    @State private var blockAppName = ""
    @State private var selectedDomains: Set<String> = []
    @State private var unifiedSearch = ""

    @AppStorage("hasSeenFirstBlockOnboarding") private var hasSeenFirstBlockOnboarding = false
    @State private var showFirstBlockOnboarding = false
    @State private var urlOnlyMode = false

    @State private var friendEmail = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false
    @State private var didFinalize = false

    var body: some View {
        NavigationStack(path: $path) {
            pickAppScreen
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .website: websiteScreen
                    case .email:   emailScreen
                    }
                }
        }
        .tint(.green)
        .onAppear {
            blockManager.beginPendingBlock()
            if !hasSeenFirstBlockOnboarding {
                showFirstBlockOnboarding = true
            }
        }
        .onDisappear {
            // Swipe-to-dismiss or Cancel before finishing → undo what we applied.
            if !didFinalize { blockManager.cancelPendingBlock() }
        }
        .sheet(isPresented: $showFirstBlockOnboarding) {
            firstBlockOnboardingSheet
        }
    }

    // MARK: - First-block onboarding (shown once)

    private var firstBlockOnboardingSheet: some View {
        VStack(spacing: 28) {
            FeatherMark(size: 52, color: .green)

            VStack(spacing: 10) {
                Text("Block just a website?")
                    .font(.title2.bold())
                Text("You can block a URL in Safari without blocking the full app on your phone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    hasSeenFirstBlockOnboarding = true
                    showFirstBlockOnboarding = false
                    urlOnlyMode = true
                    path = [.website]
                } label: {
                    Text("Block this URL")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Skip") {
                    hasSeenFirstBlockOnboarding = true
                    showFirstBlockOnboarding = false
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    // MARK: - Screen 2: Pick an App

    private var pickAppScreen: some View {
        VStack(spacing: 0) {
            screenHeader("Choose an app", accent: "to block")

            // TODO: App Store lookup (iTunes Search API) for not-installed apps.
            // Intended behavior: let users search
            // https://itunes.apple.com/search?term=QUERY&entity=software&country=us
            // and pick an app by name/icon even if it isn't on this device, then add
            // it to the block list. NOT IMPLEMENTED because it can't actually block:
            // ManagedSettings shields only accept opaque ApplicationTokens produced by
            // FamilyActivityPicker (installed apps only). There is no public API to turn
            // an App Store bundle ID into an ApplicationToken, so a non-installed app
            // cannot be shielded natively — only its website can be blocked, which the
            // "Also block the URL" screen already handles. Revisit if Apple exposes a
            // token-from-bundle-ID API.
            picker

            primaryButton("Continue", enabled: hasSelection) {
                blockManager.applyPendingAppShield(familySelection)
                path.append(.website)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear { requestAuthIfNeeded() }
        .alert("Permission Required", isPresented: $authError) {
            Button("Open Settings") { openScreenTimeSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if ProcessInfo.processInfo.isiOSAppOnMac {
                Text("1. Click OK to open System Settings.\n2. Go to Screen Time.\n3. Find BeFree in the app list and enable it.")
            } else {
                Text("Tap 'Open Settings', then go to Screen Time → BeFree to grant access.")
            }
        }
    }

    @ViewBuilder
    private var picker: some View {
        #if targetEnvironment(simulator)
        VStack(spacing: 16) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("Apple's app picker appears here on a physical device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(mockSelected ? "Selected ✓" : "Tap to simulate a selection") {
                mockSelected = true
            }
            .buttonStyle(.bordered)
            .tint(.green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        #else
        FamilyActivityPicker(selection: $familySelection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    private var hasSelection: Bool {
        #if targetEnvironment(simulator)
        return mockSelected
        #else
        return !familySelection.applicationTokens.isEmpty
            || !familySelection.categoryTokens.isEmpty
        #endif
    }

    // MARK: - Screen 3: Also block the URL

    private var websiteScreen: some View {
        VStack(spacing: 0) {
            screenHeader("Also block", accent: "the URL")

            if let message = blockManager.restrictionsStatusMessage {
                restrictionsBanner(message)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Search for an app name or website to block on the web. This step is optional.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    unifiedSearchField

                    if !filteredChips.isEmpty {
                        chipsRow
                    }

                    if !selectedDomains.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Blocking on the web")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(selectedDomains.sorted(), id: \.self) { domain in
                                selectedDomainRow(domain)
                            }
                        }
                    }

                    if !blockAppName.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "app.fill")
                                .foregroundStyle(.green)
                            Text("Blocking as: \(blockAppName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }

            primaryButton("Continue", enabled: canContinueFromWebsite) { continueFromWebsite() }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    flushUnifiedSearch()
                    syncWebBlocks(notify: true)
                    blockManager.reapplyRestrictions(notify: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh blocks")
            }
        }
        .onChange(of: selectedDomains) { _ in
            syncWebBlocks(notify: true)
        }
    }

    private func restrictionsBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                blockManager.clearRestrictionsStatus()
            }
        }
    }

    private var unifiedSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.green)
            TextField("App or website (e.g. Letterboxd, reddit.com)", text: $unifiedSearch)
                .textInputAutocapitalization(.never)
                .keyboardType(.webSearch)
                .autocorrectionDisabled()
                .onSubmit { flushUnifiedSearch() }
            if !unifiedSearch.trimmingCharacters(in: .whitespaces).isEmpty {
                Button { flushUnifiedSearch() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green, lineWidth: 1.5))
    }

    private var filteredChips: [URLChip] {
        let q = unifiedSearch.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return suggestedChips }
        return suggestedChips.filter {
            $0.name.lowercased().contains(q) || $0.domain.contains(q)
        }
    }

    private var chipsRow: some View {
        HStack(spacing: 10) {
            ForEach(filteredChips) { chip in
                chipView(chip)
            }
            Spacer(minLength: 0)
        }
    }

    private func chipView(_ chip: URLChip) -> some View {
        let isOn = selectedDomains.contains(chip.domain)
        return Button {
            if isOn {
                selectedDomains.remove(chip.domain)
            } else {
                selectedDomains.insert(chip.domain)
                if blockAppName.isEmpty { blockAppName = chip.name }
            }
            syncWebBlocks(notify: true)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle")
                    .font(.subheadline)
                Text(chip.name)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(isOn ? Color.green.opacity(0.15) : Color(.systemBackground)))
            .overlay(Capsule().stroke(isOn ? Color.green : Color(.systemGray4), lineWidth: 1))
            .foregroundStyle(isOn ? Color.green : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func selectedDomainRow(_ domain: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .foregroundStyle(.green)
            Text(domain)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                selectedDomains.remove(domain)
                syncWebBlocks(notify: true)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5), lineWidth: 1))
    }

    /// Parse the unified search box: URLs become blocked domains; plain text becomes the app name.
    private func flushUnifiedSearch() {
        let trimmed = unifiedSearch.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let chip = suggestedChips.first(where: {
            $0.name.lowercased() == trimmed.lowercased() || $0.domain == trimmed.lowercased()
        }) {
            selectedDomains.insert(chip.domain)
            if blockAppName.isEmpty { blockAppName = chip.name }
            unifiedSearch = ""
            return
        }

        let host = cleanHost(trimmed)
        if host.contains(".") {
            selectedDomains.insert(host)
            if blockAppName.isEmpty { blockAppName = titleCasedAppName(from: host) }
        } else {
            blockAppName = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        }
        unifiedSearch = ""
    }

    private func syncWebBlocks(notify: Bool) {
        blockManager.applyPendingWebDomains(Array(selectedDomains), notify: notify)
    }

    private var canContinueFromWebsite: Bool {
        !resolvedAppName.isEmpty
    }

    private var resolvedAppName: String {
        let typed = blockAppName.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty { return typed }
        let pending = unifiedSearch.trimmingCharacters(in: .whitespaces)
        if !pending.isEmpty, !pending.contains(".") {
            return pending.prefix(1).uppercased() + pending.dropFirst()
        }
        return deriveAppName(from: Array(selectedDomains))
    }

    private func continueFromWebsite() {
        flushUnifiedSearch()
        let domains = Array(selectedDomains)
        blockAppName = resolvedAppName
        syncWebBlocks(notify: true)
        path.append(.email)
    }

    /// Pick a human-readable name: typed name wins, then a known chip, then title-cased domain.
    private func deriveAppName(from domains: [String]) -> String {
        if let chip = suggestedChips.first(where: { selectedDomains.contains($0.domain) }) {
            return chip.name
        }
        if let domain = domains.first {
            return titleCasedAppName(from: domain)
        }
        return ""
    }

    private func titleCasedAppName(from domain: String) -> String {
        let base = domain.components(separatedBy: ".").first ?? domain
        guard !base.isEmpty else { return "" }
        return base.prefix(1).uppercased() + base.dropFirst()
    }

    /// Strip scheme / www / path so we store a bare host like "example.com".
    private func cleanHost(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        for prefix in ["https://", "http://", "www."] where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
        }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        return s
    }

    // MARK: - Screen 4: Friend's Email

    private var emailScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("Who's holding\nyour code?")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("Enter a trusted friend's email. They'll get the 4-digit code that unlocks the app.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                TextField("friend@example.com", text: $friendEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
                    .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            Spacer()

            primaryButton(isSubmitting ? "" : "Done", enabled: isValidEmail && !isSubmitting, showsSpinner: isSubmitting) {
                Task { await submit() }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Your friend will be notified", isPresented: $showConfirmation) {
            Button("Done") { dismiss() }
        } message: {
            Text("They've been sent the code to unlock the app. You're free until they share it.")
        }
    }

    // MARK: - Shared building blocks

    private func screenHeader(_ first: String, accent: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(first)
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
            Text(accent)
                .font(.largeTitle.bold())
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func primaryButton(
        _ title: String,
        enabled: Bool,
        showsSpinner: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if showsSpinner {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(!enabled)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Actions

    private var isValidEmail: Bool {
        let t = friendEmail.trimmingCharacters(in: .whitespaces)
        return t.contains("@") && t.contains(".")
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await blockManager.finalizePendingBlock(
                appName: blockAppName,
                friendEmail: friendEmail.trimmingCharacters(in: .whitespaces),
                userName: ""
            )
            didFinalize = true
            showConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

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
                    authError = true
                }
            case .denied:
                authError = true
            @unknown default:
                authError = true
            }
        }
        #endif
    }

    private func openScreenTimeSettings() {
        if ProcessInfo.processInfo.isiOSAppOnMac {
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
            guard let url = URL(string: "App-Prefs:SCREEN_TIME") else { return }
            UIApplication.shared.open(url) { success in
                if !success, let fallback = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(fallback)
                }
            }
        }
    }
}

#Preview {
    BlockCreationView()
        .environmentObject(BlockManager())
}
