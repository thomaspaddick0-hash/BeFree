import SwiftUI
import FamilyControls

/// Category groupings shown in the mockup-style picker list. These mirror Apple's
/// FamilyActivityPicker top-level rows but are backed by our own curated app list,
/// so our search bar can actually filter them (Apple's picker can't be filtered externally).
private struct BlockCategory: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
    let categoryKey: String?   // nil == "All Apps & Categories"
}

private let blockCategories: [BlockCategory] = [
    BlockCategory(title: "All Apps & Categories", systemImage: "square.stack.3d.up.fill", tint: .blue,   categoryKey: nil),
    BlockCategory(title: "Social",                systemImage: "bubble.left.and.bubble.right.fill", tint: .pink, categoryKey: "Social"),
    BlockCategory(title: "Games",                 systemImage: "gamecontroller.fill",     tint: .indigo, categoryKey: "Gaming"),
    BlockCategory(title: "Entertainment",         systemImage: "popcorn.fill",            tint: .orange, categoryKey: "Video"),
    BlockCategory(title: "Music",                 systemImage: "music.note",              tint: .purple, categoryKey: "Music"),
    BlockCategory(title: "Shopping",              systemImage: "cart.fill",               tint: .green,  categoryKey: "Shopping"),
    BlockCategory(title: "News",                  systemImage: "newspaper.fill",          tint: .red,    categoryKey: "News"),
    BlockCategory(title: "Dating",                systemImage: "heart.fill",              tint: .pink,   categoryKey: "Dating"),
]

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
    @State private var selectedCategory: BlockCategory?
    @FocusState private var searchFocused: Bool

    private var searchStep: some View {
        VStack(spacing: 0) {
            header

            searchBar
                .padding(.horizontal, 24)
                .padding(.top, 2)

            ScrollView {
                VStack(spacing: 0) {
                    if !query.isEmpty {
                        let results = AppDomainMap.search(query)
                        if results.isEmpty {
                            noResults
                        } else {
                            appCard(results)
                        }
                    } else if let category = selectedCategory {
                        backRow(category)
                        appCard(apps(in: category))
                    } else {
                        categoryCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.never)
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
        .onAppear { searchFocused = true }
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
        .padding(.bottom, 18)
    }

    // MARK: Search bar (styled to match mockup)

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.green)
            TextField("Search apps...", text: $query)
                .font(.body)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($searchFocused)
                .onChange(of: query) { newValue in
                    if !newValue.isEmpty { selectedCategory = nil }
                }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.green, lineWidth: 1.5)
        )
    }

    // MARK: Category list (mockup-style card)

    private var categoryCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(blockCategories.enumerated()), id: \.element.id) { index, category in
                Button {
                    searchFocused = false
                    selectedCategory = category
                } label: {
                    categoryRow(category)
                }
                .buttonStyle(.plain)

                if index < blockCategories.count - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .cardBackground()
    }

    private func categoryRow(_ category: BlockCategory) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "circle")
                .font(.system(size: 22))
                .foregroundStyle(Color(.systemGray3))
            iconTile(category.systemImage, tint: category.tint)
            Text(category.title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if category.categoryKey != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: App results (mockup-style card)

    private func appCard(_ apps: [AppEntry]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                Button { selectApp(app) } label: {
                    appRow(app)
                }
                .buttonStyle(.plain)

                if index < apps.count - 1 {
                    Divider().padding(.leading, 62)
                }
            }
        }
        .cardBackground()
    }

    private func appRow(_ app: AppEntry) -> some View {
        HStack(spacing: 14) {
            iconTile(iconFor(app), tint: tintFor(app))
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(app.domains.prefix(2).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.systemGray3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func backRow(_ category: BlockCategory) -> some View {
        Button { selectedCategory = nil } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.footnote.weight(.bold))
                Text(category.title).font(.subheadline.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.green)
            .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
    }

    private var noResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color(.systemGray4))
            Text("No results for \"\(query)\"")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: Picker-list helpers

    private func iconTile(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(tint.gradient))
    }

    private func apps(in category: BlockCategory) -> [AppEntry] {
        guard let key = category.categoryKey else { return AppDomainMap.all }
        return AppDomainMap.all.filter { $0.category == key }
    }

    private func tintFor(_ app: AppEntry) -> Color {
        blockCategories.first { $0.categoryKey == app.category }?.tint ?? .green
    }

    private func iconFor(_ app: AppEntry) -> String {
        blockCategories.first { $0.categoryKey == app.category }?.systemImage ?? "app.fill"
    }

    private func selectApp(_ app: AppEntry) {
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

private extension View {
    /// White rounded card with a hairline border and soft shadow, matching the mockup's list panel.
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
