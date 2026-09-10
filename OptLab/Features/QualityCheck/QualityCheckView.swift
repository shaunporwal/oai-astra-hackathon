import SwiftUI

struct QualityCheckView: View {
    @Environment(SessionStore.self) private var store
    let session: StudySession
    let capture: EyeCapture
    @Binding var path: [Route]

    private enum Stage: Int { case focus = 0, coverage, exposure, motion, done }
    @State private var stage: Stage = .focus
    @State private var committed = false

    private var quality: QualityReport { capture.quality }
    private var live: StudySession { store.session(id: session.id) ?? session }

    var body: some View {
        ZStack {
            AmbientBackground(warmth: 0.6)
            VStack(spacing: 18) {
                Text("Eye imaging")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.ink)
                ContextPill(segments: [session.participant.id, session.visitLabel, capture.eye.displayName])
                VStack(spacing: 6) {
                    Text(title)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.ink)
                        .contentTransition(.opacity)
                    Text(subtitle)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: stage)

                Spacer(minLength: 0)
                if stage == .done, !quality.passed {
                    failedOrb
                } else {
                    ProcessingOrb()
                }
                Spacer(minLength: 0)

                checklist
                footer
            }
            .screenPadding()
            .padding(.vertical, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await runChecks() }
    }

    // MARK: Copy

    private var title: String {
        guard stage == .done else { return "Checking your capture." }
        return quality.passed ? "\(capture.eye.displayName) passed." : "Let's retake that."
    }

    private var subtitle: String {
        guard stage == .done else { return "Confirming image quality" }
        if quality.passed {
            return live.remainingEyes.isEmpty ? "Both eyes passed quality checks." : "Ready for the \(live.remainingEyes.first?.displayName.lowercased() ?? "next eye")."
        }
        return "\(quality.failures.joined(separator: " and ")) did not meet the protocol threshold."
    }

    // MARK: Checklist

    private var checklist: some View {
        VStack(spacing: 0) {
            checkRow("Focus", check: quality.focus, revealAt: .focus)
            Divider().overlay(Theme.Colors.divider)
            checkRow("Coverage", check: quality.coverage, revealAt: .coverage)
            Divider().overlay(Theme.Colors.divider)
            checkRow("Exposure", check: quality.exposure, revealAt: .exposure)
            Divider().overlay(Theme.Colors.divider)
            checkRow("Motion check", check: quality.motion, revealAt: .motion)
        }
        .glassCard(padding: 8)
    }

    private func checkRow(_ name: String, check: QualityCheck, revealAt: Stage) -> some View {
        let revealed = stage.rawValue > revealAt.rawValue
        let active = stage == revealAt
        return HStack(spacing: 14) {
            StatusBadge(state: revealed ? (check.passed ? .passed : .failed) : (active ? .inProgress : .pending))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.ink)
                if revealed, !check.passed {
                    Text(check.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
            Spacer()
            Text(revealed ? (check.passed ? "Passed" : "Failed") : (active ? "In progress" : "Waiting"))
                .font(Theme.Typography.callout)
                .foregroundStyle(revealed ? (check.passed ? Theme.Colors.success : Theme.Colors.danger) : Theme.Colors.inkSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .animation(.easeInOut(duration: 0.25), value: stage)
    }

    private var failedOrb: some View {
        ZStack {
            Circle().fill(Theme.Colors.dangerTint).frame(width: 150, height: 150)
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Theme.Colors.danger)
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if stage == .done {
            if quality.passed {
                if let next = live.nextEye {
                    Button("Continue to \(next.displayName.lowercased())") {
                        path.removeLast(2)
                        path.append(.capture(sessionID: session.id, eye: next))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("View results") {
                        path.removeLast(2)
                        path.append(.complete(session.id))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Button("Retake \(capture.eye.displayName.lowercased())") {
                    path.removeLast(2)
                    path.append(.capture(sessionID: session.id, eye: capture.eye))
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Back to session") { path.removeLast(2) }
                    .buttonStyle(SecondaryButtonStyle())
            }
        } else {
            Text("Keep this session open")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .frame(height: 56)
        }
    }

    // MARK: Sequence

    private func runChecks() async {
        guard !committed else { return }
        let steps: [(Stage, UInt64)] = [(.coverage, 900), (.exposure, 800), (.motion, 800), (.done, 1000)]
        for (next, delay) in steps {
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
            withAnimation { stage = next }
            Haptics.tick()
        }
        committed = true
        if quality.passed {
            store.append(capture: capture, to: session.id)
            Haptics.success()
        } else {
            ImageStore.delete(fileName: capture.imageFileName)
            Haptics.warning()
        }
    }
}
