import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
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

// MARK: - Status indicators

struct StatusBadge: View {
    enum State { case passed, inProgress, pending, failed }
    let state: State

    var body: some View {
        ZStack {
            switch state {
            case .passed:
                Circle().fill(Theme.Colors.successTint)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.success)
            case .inProgress:
                DottedSpinner(color: Theme.Colors.primary)
            case .pending:
                Circle().strokeBorder(Theme.Colors.ink.opacity(0.15), lineWidth: 1.5)
            case .failed:
                Circle().fill(Theme.Colors.dangerTint)
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.danger)
            }
        }
        .frame(width: 30, height: 30)
    }
}

/// Twelve-dot rotating spinner, matching the "Motion check · In progress" glyph.
struct DottedSpinner: View {
    var color: Color = Theme.Colors.primary
    var dotCount = 12
    @State private var phase = 0

    var body: some View {
        if AppEnvironment.isUITesting {
            dots(tick: 0)
        } else {
            TimelineView(.periodic(from: .now, by: 0.08)) { context in
                dots(tick: Int(context.date.timeIntervalSinceReferenceDate / 0.08))
            }
        }
    }

    private func dots(tick: Int) -> some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { i in
                let distance = (i - tick % dotCount + dotCount) % dotCount
                Circle()
                    .fill(color.opacity(1 - Double(distance) / Double(dotCount) * 0.85))
                    .frame(width: 3.5, height: 3.5)
                    .offset(y: -11)
                    .rotationEffect(.degrees(Double(i) / Double(dotCount) * 360))
            }
        }
    }
}

/// Pulsing orb with a dotted ring — the hero of the "Checking your capture" screen.
struct ProcessingOrb: View {
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2.5, dash: [1, 8]))
                .foregroundStyle(Theme.Colors.primary.opacity(0.5))
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(breathe ? 360 : 0))
                .animation(.linear(duration: 40).repeatForever(autoreverses: false), value: breathe)

            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color.white,
                            Theme.Colors.lavender,
                            Theme.Colors.peach.opacity(0.9),
                            Theme.Colors.skyTop,
                            Color.white,
                        ],
                        center: .center
                    )
                )
                .overlay(
                    Circle().fill(
                        RadialGradient(colors: [.white.opacity(0.9), .clear], center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 110)
                    )
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 2))
                .shadow(color: Theme.Colors.primary.opacity(0.25), radius: 30, y: 16)
                .frame(width: 190, height: 190)
                .scaleEffect(breathe ? 1.03 : 0.97)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: breathe)
        }
        .onAppear { if !AppEnvironment.isUITesting { breathe = true } }
    }
}

// MARK: - Layout pieces

struct ScreenHeader: View {
    let title: String
    var trailing: AnyView? = nil
    var centered = false

    var body: some View {
        HStack {
            if centered { Spacer() }
            Text(title)
                .font(centered ? Theme.Typography.headline : Theme.Typography.title)
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
            if let trailing { trailing }
        }
    }
}

struct IconBubble: View {
    let systemName: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(Theme.Colors.primary)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.white.opacity(0.7)))
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String
    var valueTone: Color = Theme.Colors.ink

    var body: some View {
        HStack {
            Text(key).foregroundStyle(Theme.Colors.inkSecondary)
            Spacer()
            Text(value).foregroundStyle(valueTone).fontWeight(.medium)
        }
        .font(Theme.Typography.callout)
    }
}

struct ConceptFooter: View {
    var body: some View {
        Text("Investigational — not for diagnostic use")
            .font(.system(size: 11))
            .foregroundStyle(Theme.Colors.inkTertiary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
