import SwiftUI
import FamilyControls

struct BlockCreationView: View {
    @EnvironmentObject var blockManager: BlockManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedApp: AppEntry?
    @State private var step: Step = .search
    @State private var familySelection = FamilyActivitySelection()
    @State private var authError: String?

    enum Step { case search, picker, email }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .search: searchStep
                case .picker: pickerStep
                case .email:  emailStep
                }
            }
            .animation(.easeInOut, value: step)
        }
    }

    // MARK: - Step 1: Choose App

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var searchStep: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose an app")
                    .font(.largeTitle.bold())
                Text("to block")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 20)

            // Prominent search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(searchFocused || !query.isEmpty ? .green : .secondary)
                TextField("Search apps…", text: $query)
                    .font(.body)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(searchFocused ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
            .padding(.horizontal, 24)
            .onTapGesture { searchFocused = true }

            // Results / placeholder
            if query.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.system(size: 52))
                        .foregroundStyle(.green.opacity(0.25))
                    Text("Type to find the app\nyou want to quit")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                let results = AppDomainMap.search(query)
                if results.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 52))
                            .foregroundStyle(.quaternary)
                        Text("No results for \"\(query)\"")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List(results) { app in
                        Button {
                            selectedApp = app
                            familySelection = FamilyActivitySelection()
                            searchFocused = false
                            #if targetEnvironment(simulator)
                            step = .email
                            #else
                            if ProcessInfo.processInfo.isiOSAppOnMac {
                                step = .email
                            } else {
                                Task { await requestAuthAndAdvance() }
                            }
                            #endif
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(app.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(app.domains.prefix(2).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
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
        .onAppear { searchFocused = true }
    }

    // MARK: - Step 2: Apple Picker

    private var pickerStep: some View {
        #if targetEnvironment(simulator)
        EmptyView()
        #else
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Select \(selectedApp?.name ?? "the app")")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                if let category = selectedApp?.iosCategory {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.green)
                        Text("Look under **\(category)**")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.1))
                    .clipShape(Capsule())
                }

                Text("Use the search icon inside the list, then tap Continue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            FamilyActivityPicker(selection: $familySelection)
                .frame(maxHeight: .infinity)

            VStack(spacing: 12) {
                Button { step = .email } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(familySelection.applicationTokens.isEmpty)
                .padding(.horizontal)

                Button("Go back") { step = .search }
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Step 3: Friend's Email + Confirm modal

    @State private var friendEmail = ""
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

                    Text("Enter a trusted friend's email. They'll receive the 4-digit code that unlocks \(selectedApp?.name ?? "the app").")
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

                Button("Go back") {
                    #if targetEnvironment(simulator)
                    step = .search
                    #else
                    step = .picker
                    #endif
                }
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

    // MARK: - Confirm modal sheet

    private var confirmSheet: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)

                Text("Block \(selectedApp?.name ?? "")?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("\(friendEmail) will receive the unlock code.\nYou won't be able to access \(selectedApp?.name ?? "the app") until they share it.")
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

    #if !targetEnvironment(simulator)
    private func requestAuthAndAdvance() async {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved, .approvedWithDataAccess:
            step = .picker
        case .notDetermined:
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                step = .picker
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
        guard let app = selectedApp else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            #if targetEnvironment(simulator)
            try await blockManager.addBlock(
                appName: app.name,
                domains: app.domains,
                friendEmail: friendEmail.trimmingCharacters(in: .whitespaces),
                userName: ""
            )
            #else
            try await blockManager.addBlock(
                appName: app.name,
                selection: familySelection.applicationTokens.isEmpty ? nil : familySelection,
                domains: app.domains,
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

#Preview {
    BlockCreationView()
        .environmentObject(BlockManager())
}
