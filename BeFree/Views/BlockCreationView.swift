import SwiftUI
import FamilyControls

struct BlockCreationView: View {
    @EnvironmentObject var blockManager: BlockManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedApp: AppEntry?
    @State private var step: Step = .search
    @State private var familySelection = FamilyActivitySelection()
    @State private var authError: String?

    enum Step { case search, picker, email, confirm }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .search:  searchStep
                case .picker:  pickerStep
                case .email:   emailStep
                case .confirm: confirmStep
                }
            }
            .animation(.easeInOut, value: step)
        }
    }

    // MARK: - Step 1: Search

    @State private var query = ""

    private var searchStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What do you want")
                    .font(.largeTitle.bold())
                Text("to be free of?")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.green)
            }
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom, 20)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("e.g. Instagram", text: $query)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            if query.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text("Start typing to search")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                let results = AppDomainMap.search(query)
                if results.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.quaternary)
                        Text("No results for \"\(query)\"")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List(results) { app in
                        Button {
                            selectedApp = app
                            familySelection = FamilyActivitySelection()
                            #if targetEnvironment(simulator)
                            step = .email
                            #else
                            Task { await requestAuthAndAdvance() }
                            #endif
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(app.domains.prefix(2).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
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
            Button("OK") { authError = nil }
        }, message: {
            Text(authError ?? "")
        })
    }

    // MARK: - Step 2: App Picker

    private var pickerStep: some View {
        VStack(spacing: 0) {
            // Instruction banner
            VStack(spacing: 6) {
                Text("Tap \(selectedApp?.name ?? "the app") to select it")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

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

                Text("Use the search icon inside the list to find it quickly, then tap Continue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            FamilyActivityPicker(selection: $familySelection)
                .frame(maxHeight: .infinity)

            VStack(spacing: 12) {
                Button {
                    step = .email
                } label: {
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
    }

    // MARK: - Step 3: Friend's email

    @State private var friendEmail = ""

    private var emailStep: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Who's holding\nyour code?")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Enter a trusted friend's email. They'll receive the 4-digit code that unlocks \(selectedApp?.name ?? "the app").")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                TextField("friend@example.com", text: $friendEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 12) {
                Button { step = .confirm } label: {
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
    }

    // MARK: - Step 4: Confirm

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var confirmStep: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("Block \(selectedApp?.name ?? "")?")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("\(friendEmail) will receive the unlock code. You won't be able to access \(selectedApp?.name ?? "the app") or its website until they share it with you.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if let domains = selectedApp?.domains, !domains.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Also blocking:")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(domains, id: \.self) { domain in
                            Label(domain, systemImage: "globe.badge.chevron.backward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Yes, block it")
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

                Button("Go back") { step = .email }
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    #if !targetEnvironment(simulator)
    private func requestAuthAndAdvance() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            step = .picker
        } catch {
            authError = "Screen Time permission is required to block apps. Go to Settings → Screen Time and enable it."
        }
    }
    #endif

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
