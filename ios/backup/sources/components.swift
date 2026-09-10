// Adapted from feat/optlab-guided-eye-imaging, OptLab/Design/Components.swift.
import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.bodyMedium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule().fill(configuration.isPressed ? Theme.Colors.primaryPressed : Theme.Colors.primary)
            )
            .shadow(color: Theme.Colors.primary.opacity(configuration.isPressed ? 0.15 : 0.35), radius: 18, y: 10)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.bodyMedium)
            .foregroundStyle(Theme.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Chips and pills

enum ChipTone {
    case success, warning, info, neutral, danger, mint

    var foreground: Color {
        switch self {
        case .success, .mint: return Theme.Colors.success
        case .warning: return Theme.Colors.warning
        case .info: return Theme.Colors.info
        case .neutral: return Theme.Colors.inkSecondary
        case .danger: return Theme.Colors.danger
        }
    }

    var background: Color {
        switch self {
        case .success: return Theme.Colors.successTint
        case .mint: return Theme.Colors.successTint.opacity(0.8)
        case .warning: return Theme.Colors.warningTint
        case .info: return Theme.Colors.infoTint
        case .neutral: return Theme.Colors.ink.opacity(0.06)
        case .danger: return Theme.Colors.dangerTint
        }
    }
}

struct Chip: View {
    let text: String
    var tone: ChipTone = .neutral
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 12, weight: .semibold))
            }
            Text(text)
        }
        .font(Theme.Typography.caption)
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(tone.background))
    }
}

/// Glass capsule used for the session context line, e.g. "0042 · Visit 03 · Right eye".
struct ContextPill: View {
    let segments: [String]
    var emphasizeLast = true

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Text("·").foregroundStyle(Theme.Colors.inkTertiary)
                }
                Text(segment)
                    .foregroundStyle(
                        emphasizeLast && index == segments.count - 1
                            ? Theme.Colors.ink
                            : Theme.Colors.inkSecondary
                    )
                    .fontWeight(emphasizeLast && index == segments.count - 1 ? .semibold : .regular)
            }
        }
        .font(Theme.Typography.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.white.opacity(0.55)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
    }
}

