// Reused from feat/optlab-guided-eye-imaging, OptLab/Design/Theme.swift (f98f3b7).
import SwiftUI

enum AppEnvironment {
    /// Set by UI tests. Disables decorative repeat-forever animations so XCUITest can
    /// observe an idle UI; functional behaviour is unchanged.
    static let isUITesting = CommandLine.arguments.contains("--ui-testing")
}

/// Visual language shared by every screen. Values are tuned to the concept previews:
/// a soft blue–lavender field with a warm peach highlight, frosted white cards,
/// deep navy type, and a periwinkle primary action.
enum Theme {
    enum Colors {
        static let ink = Color(red: 0.11, green: 0.13, blue: 0.24)
        static let inkSecondary = Color(red: 0.42, green: 0.45, blue: 0.55)
        static let inkTertiary = Color(red: 0.58, green: 0.61, blue: 0.70)

        static let primary = Color(red: 0.443, green: 0.541, blue: 0.949)
        static let primaryPressed = Color(red: 0.37, green: 0.46, blue: 0.88)

        static let skyTop = Color(red: 0.80, green: 0.86, blue: 0.96)
        static let skyBottom = Color(red: 0.90, green: 0.92, blue: 0.98)
        static let lavender = Color(red: 0.84, green: 0.84, blue: 0.98)
        static let peach = Color(red: 0.99, green: 0.86, blue: 0.78)

        static let success = Color(red: 0.13, green: 0.55, blue: 0.36)
        static let successTint = Color(red: 0.80, green: 0.94, blue: 0.87)
        static let warning = Color(red: 0.86, green: 0.43, blue: 0.12)
        static let warningTint = Color(red: 1.00, green: 0.90, blue: 0.80)
        static let info = Color(red: 0.36, green: 0.44, blue: 0.86)
        static let infoTint = Color(red: 0.86, green: 0.89, blue: 1.00)
        static let danger = Color(red: 0.80, green: 0.22, blue: 0.25)
        static let dangerTint = Color(red: 1.00, green: 0.87, blue: 0.87)

        static let guideMint = Color(red: 0.55, green: 0.93, blue: 0.80)
        static let cardFill = Color.white.opacity(0.62)
        static let cardStroke = Color.white.opacity(0.85)
        static let divider = Color(red: 0.11, green: 0.13, blue: 0.24).opacity(0.08)
    }

    enum Radius {
        static let card: CGFloat = 28
        static let inner: CGFloat = 18
        static let chip: CGFloat = 999
    }

    enum Spacing {
        static let screen: CGFloat = 20
        static let card: CGFloat = 20
    }

    enum Typography {
        static func display(_ size: CGFloat = 40) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular)
        static let bodyMedium = Font.system(size: 17, weight: .medium)
        static let callout = Font.system(size: 15, weight: .regular)
        static let caption = Font.system(size: 13, weight: .medium)
        static let overline = Font.system(size: 12, weight: .semibold)
    }
}

// MARK: - Background

/// Full-bleed ambient background: layered gradient with a warm, blurred highlight.
struct AmbientBackground: View {
    var warmth: CGFloat = 1

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Colors.skyTop, Theme.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Theme.Colors.lavender)
                        .frame(width: geo.size.width * 1.1)
                        .blur(radius: 70)
                        .offset(x: -geo.size.width * 0.35, y: geo.size.height * 0.25)
                    Circle()
                        .fill(Theme.Colors.peach.opacity(0.9 * warmth))
                        .frame(width: geo.size.width * 0.75)
                        .blur(radius: 60)
                        .offset(x: geo.size.width * 0.45, y: -geo.size.height * 0.05)
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: geo.size.width * 0.9)
                        .blur(radius: 80)
                        .offset(x: geo.size.width * 0.1, y: geo.size.height * 0.55)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - View helpers

extension View {
    /// Frosted card treatment used for every content block.
    func glassCard(padding: CGFloat = Theme.Spacing.card, radius: CGFloat = Theme.Radius.card) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.Colors.cardFill)
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.Colors.cardStroke, lineWidth: 1)
            )
            .shadow(color: Theme.Colors.ink.opacity(0.06), radius: 24, x: 0, y: 12)
    }

    func screenPadding() -> some View {
        padding(.horizontal, Theme.Spacing.screen)
    }
}
