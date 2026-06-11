import SwiftUI

struct BlockCreationView: View {
    @EnvironmentObject var blockManager: BlockManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedApp: AppEntry?
    @State private var step: Step = .search

    enum Step { case search, confirm, email }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .search: searchStep
                case .confirm: confirmStep
                case .email: emailStep
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
                            step = .confirm
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
    }

    // MARK: - Step 2: Confirm

    private var confirmStep: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text(selectedApp?.name ?? "")
                    .font(.largeTitle.bold())

                VStack(spacing: 8) {
                    Text("Once you continue, you'll need to enter a friend's email.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Text("When you confirm, your friend will receive a 4-digit code — and you will no longer have access to this app or its website.")
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                if let domains = selectedApp?.domains, !domains.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Will also block:")
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
            }

            Spacer()

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
                .padding(.horizontal)

                Button("Go back") {
                    step = .search
                }
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Are you sure?")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Step 3: Friend's email

    @State private var friendEmail = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

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
                            Text("Finish & Block")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!isValidEmail || isSubmitting)
                .padding(.horizontal)

                Button("Go back") { step = .confirm }
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Friend's email")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isValidEmail: Bool {
        let trimmed = friendEmail.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private func submit() async {
        guard let app = selectedApp else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await blockManager.addBlock(
                appName: app.name,
                domains: app.domains,
                friendEmail: friendEmail.trimmingCharacters(in: .whitespaces)
            )
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
