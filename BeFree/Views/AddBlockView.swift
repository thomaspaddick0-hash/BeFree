import SwiftUI
import FamilyControls

struct AddBlockView: View {
    @EnvironmentObject var blockManager: BlockManager
    @Environment(\.dismiss) private var dismiss

    @State private var activitySelection = FamilyActivitySelection()
    @State private var showingPicker = false
    @State private var appName = ""
    @State private var friendEmail = ""
    @State private var customDomains = ""
    @State private var userName = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var isRequestingAuth = false

    private var suggestedDomains: [String] {
        AppDomainMap.domains(for: appName)
    }

    private var domainsToBlock: [String] {
        let custom = customDomains
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return suggestedDomains.isEmpty ? custom : suggestedDomains + custom
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your name") {
                    TextField("e.g. Alex", text: $userName)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Button {
                        Task { await requestAuthAndShowPicker() }
                    } label: {
                        Label(
                            activitySelection.applicationTokens.isEmpty ? "Choose App" : "App selected ✓",
                            systemImage: "app.badge"
                        )
                    }
                    TextField("App name (e.g. Instagram)", text: $appName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("App to block")
                } footer: {
                    Text("The app name is used to look up associated websites automatically.")
                }

                Section {
                    if !suggestedDomains.isEmpty {
                        ForEach(suggestedDomains, id: \.self) { domain in
                            Label(domain, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                        }
                    }
                    TextField("Extra domains, comma-separated", text: $customDomains)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } header: {
                    Text("Websites to block")
                } footer: {
                    Text("Associated websites are blocked automatically. Add more if needed.")
                }

                Section("Friend's email") {
                    TextField("friend@example.com", text: $friendEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Block an App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lock It") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .fontWeight(.semibold)
                }
            }
            .familyActivityPicker(isPresented: $showingPicker, selection: $activitySelection)
        }
    }

    private var canSubmit: Bool {
        !activitySelection.applicationTokens.isEmpty
        && !appName.trimmingCharacters(in: .whitespaces).isEmpty
        && !friendEmail.trimmingCharacters(in: .whitespaces).isEmpty
        && !userName.trimmingCharacters(in: .whitespaces).isEmpty
        && !domainsToBlock.isEmpty
    }

    private func requestAuthAndShowPicker() async {
        #if !targetEnvironment(simulator)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            errorMessage = "Screen Time permission is required to block apps."
            return
        }
        #endif
        showingPicker = true
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await blockManager.addBlock(
                appName: appName,
                selection: activitySelection,
                domains: domainsToBlock,
                friendEmail: friendEmail,
                userName: userName
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

#Preview {
    AddBlockView()
        .environmentObject(BlockManager())
}
