import SwiftUI

/// The BeFree feather glyph. Backed by a template asset so it tints with `color`.
struct FeatherMark: View {
    var size: CGFloat = 40
    var color: Color = .green

    var body: some View {
        Image("Feather")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The BeFree logo lockup: feather + wordmark. Use `.hero` on the login screen
/// and `.compact` for navigation bars / inline branding.
struct BeFreeWordmark: View {
    enum Style {
        case hero
        case compact

        var featherSize: CGFloat {
            switch self {
            case .hero: return 64
            case .compact: return 22
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .hero: return 44
            case .compact: return 20
            }
        }

        var spacing: CGFloat {
            switch self {
            case .hero: return 8
            case .compact: return 6
            }
        }
    }

    var style: Style = .hero
    var color: Color = .green

    var body: some View {
        switch style {
        case .hero:
            VStack(spacing: style.spacing) {
                FeatherMark(size: style.featherSize, color: color)
                wordmarkText
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("BeFree")
        case .compact:
            HStack(spacing: style.spacing) {
                FeatherMark(size: style.featherSize, color: color)
                wordmarkText
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("BeFree")
        }
    }

    private var wordmarkText: some View {
        Text("BeFree")
            .font(.system(size: style.fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
    }
}

#Preview {
    VStack(spacing: 40) {
        BeFreeWordmark(style: .hero)
        BeFreeWordmark(style: .compact)
        FeatherMark(size: 30, color: .secondary)
    }
    .padding()
}
