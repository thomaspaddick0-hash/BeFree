import Foundation
import UIKit
import CryptoKit
import Supabase

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    @Published var isSignedIn = false

    let client = SupabaseClient(
        supabaseURL: URL(string: Secrets.supabaseURL)!,
        supabaseKey: Secrets.supabaseAnonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true)
        )
    )

    private init() {
        Task { await observeAuthState() }
    }

    var currentUserID: UUID? { client.auth.currentUser?.id }

    /// Best available display name from the signed-in user's auth profile (Google/Apple metadata).
    var currentUserDisplayName: String {
        guard let user = client.auth.currentUser else { return "Someone" }
        for key in ["full_name", "name"] {
            if let val = user.userMetadata[key],
               let data = try? JSONEncoder().encode(val),
               let name = try? JSONDecoder().decode(String.self, from: data),
               !name.isEmpty {
                return name
            }
        }
        return user.email?.components(separatedBy: "@").first ?? "Someone"
    }

    var currentUserEmail: String? { client.auth.currentUser?.email }

    /// Up to two uppercase initials from the display name (falls back to email).
    var currentUserInitials: String {
        let parts = currentUserDisplayName.split(separator: " ").prefix(2)
        let initials = parts.compactMap(\.first).map(String.init).joined()
        if !initials.isEmpty { return initials.uppercased() }
        return currentUserEmail?.first.map { String($0).uppercased() } ?? "?"
    }

    /// Friendly name of the auth provider used (e.g. "Google", "Apple").
    var currentUserProvider: String {
        switch client.auth.currentUser?.identities?.first?.provider {
        case "google": return "Google"
        case "apple":  return "Apple"
        case "email":  return "Email"
        case .some(let other) where !other.isEmpty: return other.capitalized
        default: return ""
        }
    }

    // MARK: - Auth

    private func observeAuthState() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .initialSession:
                isSignedIn = session != nil
            case .signedIn, .tokenRefreshed, .userUpdated:
                isSignedIn = true
            case .signedOut:
                isSignedIn = false
            default:
                break
            }
        }
    }

    /// Presents Google sign-in in an in-app ASWebAuthenticationSession and completes the
    /// session exchange internally — no external Safari round-trip required.
    func signInWithGoogle() async throws {
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "befree://auth-callback")
        )
    }

    /// Kept for any external-browser callbacks (e.g. magic links) that re-enter via the URL scheme.
    func handleAuthCallback(url: URL) async {
        _ = try? await client.auth.session(from: url)
    }

    /// Sign in with an Apple ID token obtained from ASAuthorizationAppleIDProvider.
    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Verifies a session exists; throws if the user is not signed in.
    func signInIfNeeded() async throws {
        _ = try await client.auth.session
    }

    // MARK: - Blocks

    func fetchActiveBlocks() async throws -> [Block] {
        let rows: [SupabaseBlock] = try await client
            .from("blocks")
            .select()
            .filter("unlocked_at", operator: "is", value: "null")
            .execute()
            .value
        return rows.map(\.block)
    }

    func insertBlock(_ block: Block, code: String, userID: UUID) async throws {
        let payload = SupabaseBlock(
            from: block,
            code: code,
            codeHash: sha256(code),
            userID: userID,
            userName: currentUserDisplayName
        )
        try await client.from("blocks").insert(payload).execute()
    }

    /// Returns blocks where the current user is the designated code-holder.
    /// Requires a Supabase RLS policy: friend_email = auth.email()
    func fetchBlocksImHolding() async throws -> [HeldBlock] {
        guard let email = client.auth.currentUser?.email else { return [] }

        struct HeldRow: Decodable {
            let id: String
            let appName: String
            let code: String?
            let userName: String?
            let blockedAt: String
            enum CodingKeys: String, CodingKey {
                case id, appName = "app_name", code, userName = "user_name", blockedAt = "blocked_at"
            }
        }

        let rows: [HeldRow] = try await client
            .from("blocks")
            .select("id, app_name, code, user_name, blocked_at")
            .eq("friend_email", value: email)
            .filter("unlocked_at", operator: "is", value: "null")
            .execute()
            .value

        return rows.compactMap { row in
            guard let code = row.code else { return nil }
            return HeldBlock(
                id: UUID(uuidString: row.id) ?? UUID(),
                blockerName: row.userName ?? "Your friend",
                appName: row.appName,
                code: code,
                blockedAt: ISO8601DateFormatter().date(from: row.blockedAt) ?? Date()
            )
        }
    }

    func verifyAndUnlock(blockId: UUID, code: String) async throws {
        let rows: [SupabaseBlock] = try await client
            .from("blocks")
            .select()
            .eq("id", value: blockId.uuidString)
            .execute()
            .value
        guard let stored = rows.first else { throw BeFreeError.blockNotFound }
        guard stored.codeHash == sha256(code) else { throw BeFreeError.wrongCode }

        struct UnlockPayload: Encodable {
            let unlocked_at: String
        }
        try await client
            .from("blocks")
            .update(UnlockPayload(unlocked_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: blockId.uuidString)
            .execute()
    }

    private func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Supabase DTO

private struct SupabaseBlock: Codable {
    var id: String
    var userId: String
    var appName: String
    var blockedDomains: [String]
    var friendEmail: String
    var code: String?
    var codeHash: String
    var userName: String?
    var blockedAt: String
    var unlockedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", appName = "app_name"
        case friendEmail = "friend_email", blockedDomains = "blocked_domains"
        case code, codeHash = "code_hash", userName = "user_name"
        case blockedAt = "blocked_at", unlockedAt = "unlocked_at"
    }

    init(from block: Block, code: String, codeHash: String, userID: UUID, userName: String) {
        self.id = block.id.uuidString
        self.userId = userID.uuidString
        self.appName = block.appName
        self.blockedDomains = block.blockedDomains
        self.friendEmail = block.friendEmail
        self.code = code
        self.codeHash = codeHash
        self.userName = userName
        self.blockedAt = ISO8601DateFormatter().string(from: block.blockedAt)
        self.unlockedAt = block.unlockedAt.map { ISO8601DateFormatter().string(from: $0) }
    }

    var block: Block {
        Block(
            id: UUID(uuidString: id) ?? UUID(),
            appName: appName,
            blockedDomains: blockedDomains,
            friendEmail: friendEmail,
            blockedAt: ISO8601DateFormatter().date(from: blockedAt) ?? Date(),
            unlockedAt: unlockedAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }
}

// MARK: - Errors

enum BeFreeError: LocalizedError {
    case serverError, blockNotFound, wrongCode, notSignedIn

    var errorDescription: String? {
        switch self {
        case .serverError: return "Something went wrong. Please try again."
        case .blockNotFound: return "Block not found — try restarting the app and unlocking again."
        case .wrongCode: return "Incorrect code. Double-check each digit with your friend."
        case .notSignedIn: return "Not signed in. Please restart the app."
        }
    }
}

enum ResendError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        if case .failed(let body) = self { return "Email failed: \(body)" }
        return nil
    }
}
