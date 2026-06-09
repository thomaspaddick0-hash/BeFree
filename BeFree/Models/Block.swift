import Foundation
import FamilyControls

struct Block: Identifiable, Codable {
    let id: UUID
    let appName: String
    let blockedDomains: [String]
    let friendEmail: String
    let blockedAt: Date
    var unlockedAt: Date?

    // Stored as base64 in Supabase; not Codable natively so we handle it separately
    var activitySelectionData: Data?

    var isActive: Bool { unlockedAt == nil }

    var elapsed: TimeInterval { Date().timeIntervalSince(blockedAt) }

    static func elapsedString(from interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
