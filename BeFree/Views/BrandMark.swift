import SwiftUI

/// The BeFree feather glyph from the original artwork.
/// Uses alpha masking (not template mode) so iOS tints the silhouette correctly.
struct FeatherMark: View {
    var size: CGFloat = 40
    var color: Color = .green

    private var featherWidth: CGFloat { size * 0.88 }

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: featherWidth, height: size)
            .mask {
                Image("Feather")
                    .resizable()
                    .scaledToFit()
                    .frame(width: featherWidth, height: size)
            }
            .accessibilityHidden(true)
    }
}

/// The BeFree logo lockup: wordmark + feather. Use `.hero` on splash/login screens
/// and `.compact` for navigation bars / inline branding.
struct BeFreeWordmark: View {
    enum Style {
        case hero
        case compact
        case horizontalHero

        var featherSize: CGFloat {
            switch self {
            case .hero: return 64
            case .compact: return 22
            case .horizontalHero: return 52
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .hero: return 44
            case .compact: return 20
            case .horizontalHero: return 36
            }
        }

        var spacing: CGFloat {
            switch self {
            case .hero: return 8
            case .compact: return 6
            case .horizontalHero: return 12
            }
        }

        var isHorizontal: Bool {
            switch self {
            case .hero: return false
            case .compact, .horizontalHero: return true
            }
        }
    }

    var style: Style = .hero
    var color: Color = .green
    var textColor: Color = .primary

    var body: some View {
        Group {
            if style.isHorizontal {
                HStack(spacing: style.spacing) {
                    wordmarkText
                    FeatherMark(size: style.featherSize, color: color)
                }
            } else {
                VStack(spacing: style.spacing) {
                    wordmarkText
                    FeatherMark(size: style.featherSize, color: color)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BeFree")
    }

    private var wordmarkText: some View {
        Text("BeFree")
            .font(.system(size: style.fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
    }
}

#Preview {
    VStack(spacing: 40) {
        BeFreeWordmark(style: .hero, color: .green, textColor: .primary)
        BeFreeWordmark(style: .horizontalHero, color: Color(red: 0.10, green: 0.14, blue: 0.49), textColor: Color(red: 0.10, green: 0.14, blue: 0.49))
        BeFreeWordmark(style: .compact)
        ZStack {
            Color(red: 0.10, green: 0.14, blue: 0.49)
            BeFreeWordmark(style: .horizontalHero, color: .white, textColor: .white)
        }
        .frame(height: 120)
    }
    .padding()
}
