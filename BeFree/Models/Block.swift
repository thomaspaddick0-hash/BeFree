import Foundation
import FamilyControls

/// A block that the current user is holding a code for on behalf of a friend.
struct HeldBlock: Identifiable {
    let id: UUID
    let blockerName: String   // display name of the person who created the block
    let appName: String
    let code: String          // plaintext 4-digit code — only visible to the code-holder
    let blockedAt: Date

    var elapsed: TimeInterval { Date().timeIntervalSince(blockedAt) }
}

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

    /// Progressive format that scales with how long the block has lasted:
    /// - under 24h:   `HH:MM:SS`
    /// - 1–7 days:    `D days, HH:MM`
    /// - 7–30 days:   `W weeks, D days, HH:MM`
    /// - 30+ days:    `M months, W weeks, D days`
    /// Uses approximate week = 7 days and month = 30 days for the breakpoints.
    static func elapsedString(from interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let daysTotal = total / 86_400
        let h = (total % 86_400) / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        let hhmm = String(format: "%02d:%02d", h, m)

        if total < 86_400 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else if daysTotal < 7 {
            return "\(unit(daysTotal, "day")), \(hhmm)"
        } else if daysTotal < 30 {
            let weeks = daysTotal / 7
            let days = daysTotal % 7
            return "\(unit(weeks, "week")), \(unit(days, "day")), \(hhmm)"
        } else {
            let months = daysTotal / 30
            let remDays = daysTotal % 30
            let weeks = remDays / 7
            let days = remDays % 7
            return "\(unit(months, "month")), \(unit(weeks, "week")), \(unit(days, "day"))"
        }
    }

    /// "1 day" / "3 days" — grammatically correct singular vs plural.
    private static func unit(_ value: Int, _ singular: String) -> String {
        "\(value) \(singular)\(value == 1 ? "" : "s")"
    }
}
