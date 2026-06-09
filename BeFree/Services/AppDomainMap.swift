import Foundation

enum AppDomainMap {
    static let known: [String: [String]] = [
        "Instagram":   ["instagram.com", "www.instagram.com"],
        "TikTok":      ["tiktok.com", "www.tiktok.com"],
        "Twitter":     ["twitter.com", "x.com", "www.twitter.com"],
        "YouTube":     ["youtube.com", "www.youtube.com", "youtu.be", "m.youtube.com"],
        "Facebook":    ["facebook.com", "www.facebook.com", "m.facebook.com"],
        "Reddit":      ["reddit.com", "www.reddit.com", "old.reddit.com"],
        "Snapchat":    ["snapchat.com", "www.snapchat.com"],
        "LinkedIn":    ["linkedin.com", "www.linkedin.com"],
        "Pinterest":   ["pinterest.com", "www.pinterest.com"],
        "Twitch":      ["twitch.tv", "www.twitch.tv"],
        "Discord":     ["discord.com", "www.discord.com"],
        "BeReal":      ["bere.al", "bereal.com"],
    ]

    static func domains(for appName: String) -> [String] {
        // Case-insensitive prefix match
        if let exact = known[appName] { return exact }
        let lower = appName.lowercased()
        return known.first(where: { $0.key.lowercased().hasPrefix(lower) })?.value ?? []
    }
}
