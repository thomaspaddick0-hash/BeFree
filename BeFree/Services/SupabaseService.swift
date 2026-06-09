import Foundation
import CryptoKit

// Requires: supabase-swift package
// https://github.com/supabase/supabase-swift

final class SupabaseService {
    static let shared = SupabaseService()

    // TODO: Replace with your Supabase project URL and anon key
    private let url = URL(string: "https://YOUR_PROJECT.supabase.co")!
    private let anonKey = "YOUR_SUPABASE_ANON_KEY"

    private var headers: [String: String] {
        ["apikey": anonKey, "Authorization": "Bearer \(anonKey)", "Content-Type": "application/json"]
    }

    func fetchActiveBlocks() async throws -> [Block] {
        var req = URLRequest(url: url.appendingPathComponent("rest/v1/blocks"))
        req.allHTTPHeaderFields = headers
        req.url?.append(queryItems: [URLQueryItem(name: "unlocked_at", value: "is.null")])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([SupabaseBlock].self, from: data).map(\.block)
    }

    func insertBlock(_ block: Block, code: String) async throws {
        var req = URLRequest(url: url.appendingPathComponent("rest/v1/blocks"))
        req.httpMethod = "POST"
        req.allHTTPHeaderFields = headers
        let payload = SupabaseBlock(from: block, codeHash: sha256(code))
        req.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 201 else { throw BeFreeError.serverError }
    }

    func verifyAndUnlock(blockId: UUID, code: String) async throws {
        // Fetch the block to check the hash
        var req = URLRequest(url: url.appendingPathComponent("rest/v1/blocks"))
        req.allHTTPHeaderFields = headers
        req.url?.append(queryItems: [URLQueryItem(name: "id", value: "eq.\(blockId.uuidString)")])
        let (data, _) = try await URLSession.shared.data(for: req)
        let blocks = try JSONDecoder().decode([SupabaseBlock].self, from: data)
        guard let stored = blocks.first else { throw BeFreeError.blockNotFound }
        guard stored.codeHash == sha256(code) else { throw BeFreeError.wrongCode }

        // Mark unlocked
        var patchReq = URLRequest(url: url.appendingPathComponent("rest/v1/blocks"))
        patchReq.httpMethod = "PATCH"
        patchReq.allHTTPHeaderFields = headers
        patchReq.url?.append(queryItems: [URLQueryItem(name: "id", value: "eq.\(blockId.uuidString)")])
        patchReq.httpBody = try JSONEncoder().encode(["unlocked_at": ISO8601DateFormatter().string(from: Date())])
        let (_, patchResponse) = try await URLSession.shared.data(for: patchReq)
        guard (patchResponse as? HTTPURLResponse)?.statusCode == 204 else { throw BeFreeError.serverError }
    }

    private func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Supabase DTO

private struct SupabaseBlock: Codable {
    var id: String
    var appName: String
    var blockedDomains: [String]
    var friendEmail: String
    var codeHash: String
    var blockedAt: String
    var unlockedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, friendEmail = "friend_email", appName = "app_name"
        case blockedDomains = "blocked_domains", codeHash = "code_hash"
        case blockedAt = "blocked_at", unlockedAt = "unlocked_at"
    }

    init(from block: Block, codeHash: String) {
        self.id = block.id.uuidString
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
    case serverError, blockNotFound, wrongCode

    var errorDescription: String? {
        switch self {
        case .serverError: return "Something went wrong. Please try again."
        case .blockNotFound: return "Block not found."
        case .wrongCode: return "That code is incorrect. Ask your friend again."
        }
    }
}
