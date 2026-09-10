import SwiftUI
import AVFoundation

struct SessionView: View {
    @Environment(SessionStore.self) private var store
    let session: StudySession
    @Binding var path: [Route]

    @State private var heroImage: CGImage?
    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    private var live: StudySession { store.session(id: session.id) ?? session }

    var body: some View {
        ZStack {
            AmbientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Eye imaging")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.ink)
                    hero
                    sessionCard
                    if live.status == .complete {
                        Button("View results") { path.append(.complete(live.id)) }
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button(action: begin) {
                            Text(live.captures.isEmpty ? "Begin guided capture" : "Continue guided capture")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!live.consentRecorded)
                    }
                    Button("View protocol") { path.append(.protocolDetail(live.id)) }
                        .buttonStyle(SecondaryButtonStyle())
                    ConceptFooter()
                }
                .screenPadding()
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .task { await loadHero() }
        .onAppear { cameraStatus = AVCaptureDevice.authorizationStatus(for: .video) }
    }

    private func begin() {
        guard let eye = live.nextEye else { return }
        path.append(.capture(sessionID: live.id, eye: eye))
    }

    private var hero: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Theme.Colors.lavender)
            .overlay {
                if let heroImage {
                    Image(decorative: heroImage, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: Theme.Colors.ink.opacity(0.08), radius: 24, y: 12)
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CAPTURE SESSION")
                .font(Theme.Typography.overline)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .kerning(1)
            VStack(alignment: .leading, spacing: 4) {
                Text(live.participant.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.ink)
                Text("\(live.visitLabel) · \(live.imagingProtocol.name)")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            VStack(spacing: 10) {
                ForEach(Array(live.imagingProtocol.eyes.enumerated()), id: \.element) { index, eye in
                    EyeStepRow(index: index + 1, eye: eye, state: state(for: eye))
                }
            }
            Divider().overlay(Theme.Colors.divider)
            HStack(spacing: 8) {
                StatusBadge(state: readiness.allGood ? .passed : .pending).frame(width: 24, height: 24)
                Text(readiness.text)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
        }
        .glassCard()
    }

    private func state(for eye: Eye) -> EyeStepRow.State {
        if live.capture(for: eye) != nil { return .done }
        let remaining = live.remainingEyes
        guard let index = remaining.firstIndex(of: eye) else { return .queued }
        if index == 0 { return live.captures.isEmpty ? .first : .next }
        return index == 1 && live.captures.isEmpty ? .next : .queued
    }

    private var readiness: (allGood: Bool, text: String) {
        var parts: [String] = []
        parts.append(live.consentRecorded ? "Consent recorded" : "Consent missing")
        #if targetEnvironment(simulator)
        let deviceReady = true
        #else
        let deviceReady = cameraStatus == .authorized || cameraStatus == .notDetermined
        #endif
        parts.append(deviceReady ? "Device ready" : "Camera access needed")
        return (live.consentRecorded && deviceReady, parts.joined(separator: " · "))
    }

    private func loadHero() async {
        if let capture = live.captures.last, let ui = ImageStore.load(fileName: capture.imageFileName), let cg = ui.cgImage {
            heroImage = cg
            return
        }
        heroImage = await Task.detached {
            var scene = SyntheticEyeRenderer.Scene()
            scene.irisCenter = CGPoint(x: 0.5, y: 0.5)
            scene.irisRadius = 0.13
            scene.pupilRatio = 0.4
            scene.redness = 0.04
            return SyntheticEyeRenderer.render(size: CGSize(width: 900, height: 480), scene: scene)
        }.value
    }
}

struct EyeStepRow: View {
    enum State { case first, next, done, queued }
    let index: Int
    let eye: Eye
    let state: State

    var body: some View {
        HStack(spacing: 14) {
            Text("\(index)")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.ink)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.8)))
            Text(eye.displayName)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
            switch state {
            case .first: Chip(text: "First", tone: .mint)
            case .next: Chip(text: "Next", tone: .info)
            case .done: Chip(text: "Passed", tone: .success, systemImage: "checkmark")
            case .queued: Chip(text: "Queued", tone: .neutral)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
    }
}
