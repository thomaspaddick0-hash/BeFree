import SwiftUI
import FamilyControls

/// One of the most common apps people block, shown as a big button on the
/// "Block the Website" screen. Domains come from `AppDomainMap` so the web
/// filter stays in sync with the rest of the app.
private struct CommonApp: Identifiable {
    let id = UUID()
    let name: String
    let monogram: String
    let tint: Color
    var domains: [String] { AppDomainMap.domains(for: name) }
}

private let commonApps: [CommonApp] = [
    CommonApp(name: "Instagram", monogram: "Ig", tint: Color(red: 0.83, green: 0.18, blue: 0.51)),
    CommonApp(name: "TikTok",    monogram: "Tt", tint: .black),
    CommonApp(name: "Snapchat",  monogram: "Sc", tint: Color(red: 0.98, green: 0.78, blue: 0.10)),
    CommonApp(name: "YouTube",   monogram: "Yt", tint: Color(red: 0.90, green: 0.13, blue: 0.13)),
    CommonApp(name: "X",         monogram: "X",  tint: .black),
    CommonApp(name: "Facebook",  monogram: "Fb", tint: Color(red: 0.10, green: 0.40, blue: 0.92)),
]

struct BlockCreationView: View {
    @EnvironmentObject var blockManager: BlockManager
    @Environment(\.dismiss) private var dismiss

    private enum Step: Hashable { case website, customURL, email }

    @State private var path: [Step] = []

    @State private var familySelection = FamilyActivitySelection()
    @State private var mockSelected = false            // simulator-only stand-in
    @State private var authError = false

    // What we'll record + email. Filled in on the website screen.
    @State private var blockAppName = "your app"
    @State private var blockDomains: [String] = []
    @State private var customURL = ""

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
                    case .website:   websiteScreen
                    case .customURL: customURLScreen
                    case .email:     emailScreen
                    }
                }
        }
        .tint(.green)
        .onAppear { blockManager.beginPendingBlock() }
        .onDisappear {
            // Swipe-to-dismiss or Cancel before finishing → undo what we applied.
            if !didFinalize { blockManager.cancelPendingBlock() }
        }
    }

    // MARK: - Screen 2: Pick an App

    private var pickAppScreen: some View {
        VStack(spacing: 0) {
            screenHeader("Choose an app", accent: "to block")

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

    // MARK: - Screen 3: Block the Website

    private var websiteScreen: some View {
        VStack(spacing: 0) {
            screenHeader("Which app", accent: "did you pick?")

            Text("Tap it so we can block its website too.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(commonApps) { app in
                        Button {
                            select(name: app.name, domains: app.domains)
                        } label: {
                            appButtonLabel(monogram: app.monogram, tint: app.tint, title: app.name)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        path.append(.customURL)
                    } label: {
                        appButtonLabel(monogram: "?", tint: Color(.systemGray), title: "My app isn't listed")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func appButtonLabel(monogram: String, tint: Color, title: String) -> some View {
        HStack(spacing: 16) {
            Text(monogram)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(tint.gradient))
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(.systemGray3))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5), lineWidth: 1))
        .contentShape(Rectangle())
    }

    private func select(name: String, domains: [String]) {
        blockAppName = name
        blockDomains = domains
        blockManager.applyPendingWebDomains(domains)
        path.append(.email)
    }

    // MARK: - Screen 3b: Custom URL / Skip

    private var customURLScreen: some View {
        VStack(spacing: 0) {
            screenHeader("Block a", accent: "website")

            VStack(alignment: .leading, spacing: 12) {
                Text("Enter the website you want to block, or skip and just block the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("example.com", text: $customURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                primaryButton("Block this website", enabled: !cleanedHost.isEmpty) {
                    select(name: cleanedHost, domains: [cleanedHost])
                }
                Button("Skip — just block the app") {
                    select(name: blockAppName == "your app" ? "your app" : blockAppName, domains: [])
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Strip scheme / www / path so we store a bare host like "example.com".
    private var cleanedHost: String {
        var s = customURL.trimmingCharacters(in: .whitespaces).lowercased()
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
