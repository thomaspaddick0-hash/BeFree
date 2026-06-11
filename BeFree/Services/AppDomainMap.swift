import Foundation

struct AppEntry: Identifiable {
    let id = UUID()
    let name: String
    let domains: [String]
    let category: String
}

struct AppDomainMap {
    static let all: [AppEntry] = [
        // Social
        AppEntry(name: "Instagram",   domains: ["instagram.com", "cdninstagram.com"],                     category: "Social"),
        AppEntry(name: "TikTok",      domains: ["tiktok.com", "tiktokv.com", "tiktokcdn.com"],            category: "Social"),
        AppEntry(name: "Twitter",     domains: ["twitter.com", "x.com", "t.co"],                          category: "Social"),
        AppEntry(name: "X",           domains: ["x.com", "twitter.com", "t.co"],                          category: "Social"),
        AppEntry(name: "Facebook",    domains: ["facebook.com", "fb.com", "fbcdn.net", "messenger.com"],  category: "Social"),
        AppEntry(name: "Snapchat",    domains: ["snapchat.com"],                                          category: "Social"),
        AppEntry(name: "BeReal",      domains: ["bere.al", "bereal.com"],                                 category: "Social"),
        AppEntry(name: "LinkedIn",    domains: ["linkedin.com"],                                          category: "Social"),
        AppEntry(name: "Pinterest",   domains: ["pinterest.com", "pinimg.com"],                           category: "Social"),
        AppEntry(name: "Reddit",      domains: ["reddit.com", "redd.it", "redditmedia.com"],              category: "Social"),
        AppEntry(name: "Tumblr",      domains: ["tumblr.com"],                                            category: "Social"),
        AppEntry(name: "Discord",     domains: ["discord.com", "discordapp.com", "discord.gg"],           category: "Social"),
        AppEntry(name: "Threads",     domains: ["threads.net"],                                           category: "Social"),
        AppEntry(name: "WhatsApp",    domains: ["whatsapp.com", "web.whatsapp.com"],                      category: "Social"),
        AppEntry(name: "Telegram",    domains: ["telegram.org", "web.telegram.org"],                      category: "Social"),

        // Video
        AppEntry(name: "YouTube",     domains: ["youtube.com", "youtu.be", "googlevideo.com", "ytimg.com"], category: "Video"),
        AppEntry(name: "Netflix",     domains: ["netflix.com"],                                           category: "Video"),
        AppEntry(name: "Twitch",      domains: ["twitch.tv", "twitchapps.com"],                           category: "Video"),
        AppEntry(name: "Disney+",     domains: ["disneyplus.com", "bamgrid.com"],                         category: "Video"),
        AppEntry(name: "HBO Max",     domains: ["max.com", "hbomax.com", "hbo.com"],                      category: "Video"),
        AppEntry(name: "Hulu",        domains: ["hulu.com"],                                              category: "Video"),
        AppEntry(name: "Prime Video", domains: ["primevideo.com"],                                        category: "Video"),
        AppEntry(name: "Peacock",     domains: ["peacocktv.com"],                                         category: "Video"),
        AppEntry(name: "Paramount+",  domains: ["paramountplus.com"],                                     category: "Video"),
        AppEntry(name: "Apple TV+",   domains: ["tv.apple.com"],                                          category: "Video"),

        // Music
        AppEntry(name: "Spotify",     domains: ["open.spotify.com", "spotify.com"],                       category: "Music"),
        AppEntry(name: "SoundCloud",  domains: ["soundcloud.com"],                                        category: "Music"),
        AppEntry(name: "Apple Music", domains: ["music.apple.com"],                                       category: "Music"),

        // Shopping
        AppEntry(name: "Amazon",      domains: ["amazon.com", "amazon.co.uk", "amazon.ca"],               category: "Shopping"),
        AppEntry(name: "eBay",        domains: ["ebay.com", "ebay.co.uk"],                                category: "Shopping"),
        AppEntry(name: "ASOS",        domains: ["asos.com"],                                              category: "Shopping"),
        AppEntry(name: "Etsy",        domains: ["etsy.com"],                                              category: "Shopping"),
        AppEntry(name: "Shein",       domains: ["shein.com"],                                             category: "Shopping"),
        AppEntry(name: "Zara",        domains: ["zara.com"],                                              category: "Shopping"),

        // Gaming
        AppEntry(name: "Roblox",      domains: ["roblox.com", "rbxcdn.com"],                              category: "Gaming"),
        AppEntry(name: "Steam",       domains: ["store.steampowered.com", "steampowered.com"],            category: "Gaming"),

        // News
        AppEntry(name: "BBC News",    domains: ["bbc.com", "bbc.co.uk"],                                  category: "News"),
        AppEntry(name: "CNN",         domains: ["cnn.com"],                                               category: "News"),
        AppEntry(name: "Daily Mail",  domains: ["dailymail.co.uk"],                                       category: "News"),
        AppEntry(name: "BuzzFeed",    domains: ["buzzfeed.com"],                                          category: "News"),

        // Dating
        AppEntry(name: "Tinder",      domains: ["tinder.com"],                                            category: "Dating"),
        AppEntry(name: "Bumble",      domains: ["bumble.com"],                                            category: "Dating"),
        AppEntry(name: "Hinge",       domains: ["hinge.co"],                                              category: "Dating"),
    ]

    static func search(_ query: String) -> [AppEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return all.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    static func domains(for name: String) -> [String] {
        all.first { $0.name.localizedCaseInsensitiveContains(name) }?.domains ?? []
    }
}
