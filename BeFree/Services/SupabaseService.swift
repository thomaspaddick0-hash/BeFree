import Foundation
import CryptoKit
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()

    let client = SupabaseClient(
        supabaseURL: URL(string: Secrets.supabaseURL)!,
        supabaseKey: Secrets.supabaseAnonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true)
        )
    )

    var currentUserID: UUID? {
        client.auth.currentUser?.id
    }

    func signInIfNeeded() async throws {
        do {
            _ = try await client.auth.session
        } catch {
            try await client.auth.signInAnonymously()
        }
    }

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
        let payload = SupabaseBlock(from: block, codeHash: sha256(code), userID: userID)
        try await client.from("blocks").insert(payload).execute()
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
    var codeHash: String
    var blockedAt: String
    var unlockedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", appName = "app_name"
        case friendEmail = "friend_email", blockedDomains = "blocked_domains"
        case codeHash = "code_hash", blockedAt = "blocked_at", unlockedAt = "unlocked_at"
    }

    init(from block: Block, codeHash: String, userID: UUID) {
        self.id = block.id.uuidString
        self.userId = userID.uuidString
        self.appName = block.appName
        self.blockedDomains = block.blockedDomains
        self.friendEmail = block.friendEmail
        self.codeHash = codeHash
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

enum BeFreeError: LocalizedError {
    case serverError, blockNotFound, wrongCode, notSignedIn

    var errorDescription: String? {
        switch self {
        case .serverError: return "Something went wrong. Please try again."
        case .blockNotFound: return "Block not found."
        case .wrongCode: return "That code is incorrect. Ask your friend again."
        case .notSignedIn: return "Not signed in. Please restart the app."
        }
    }
}
