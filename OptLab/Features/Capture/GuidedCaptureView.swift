import SwiftUI
import OSLog

struct GuidedCaptureView: View {
    @Environment(SessionStore.self) private var store
    let session: StudySession
    let eye: Eye
    @Binding var path: [Route]

    @State private var controller: CaptureSessionController
    @AppStorage("voiceGuidanceEnabled") private var voiceEnabled = true
    @AppStorage("autoCaptureEnabled") private var autoCapture = true
    @State private var didNavigate = false

    init(session: StudySession, eye: Eye, path: Binding<[Route]>) {
        self.session = session
        self.eye = eye
        self._path = path
        _controller = State(initialValue: CaptureSessionController(eye: eye, imagingProtocol: session.imagingProtocol))
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 14) {
                header
                ContextPill(segments: [session.participant.id, session.visitLabel, eye.displayName])
                instruction
                viewfinder
                statusChips
                autoCaptureCard
                voiceRow
                Spacer(minLength: 0)
            }
            .screenPadding()
            .padding(.bottom, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            controller.voiceEnabled = voiceEnabled
            controller.autoCaptureEnabled = autoCapture
            await controller.start()
        }
        .onDisappear { controller.stop() }
        .onChange(of: voiceEnabled) { _, new in controller.voiceEnabled = new }
        .onChange(of: autoCapture) { _, new in controller.autoCaptureEnabled = new }
        .onChange(of: controller.phase) { _, phase in
            if case .captured(let capture) = phase, !didNavigate {
                didNavigate = true
                Logger(subsystem: "com.optlab.eyeimaging", category: "nav")
                    .notice("push qualityCheck eye=\(capture.eye.rawValue, privacy: .public) depth=\(path.count)")
                path.append(.qualityCheck(sessionID: session.id, capture: capture))
            }
        }
        .overlay { failureOverlay }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button {
                controller.stop()
                path.removeLast()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.7)))
            }
            Text("Eye imaging")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
            Menu {
                Button("Capture now", systemImage: "camera") { controller.captureNow() }
                    .disabled(controller.phase != .live)
                Toggle("Auto-capture", systemImage: "scope", isOn: $autoCapture)
                Toggle("Voice guidance", systemImage: "speaker.wave.2", isOn: $voiceEnabled)
                if let profile = controller.profile {
                    Section("Optics") {
                        Text("\(profile.name) · \(profile.zoomFactor, specifier: "%.1f")×")
                        if let d = controller.workingDistanceText { Text("Working distance \(d)") }
                        if let r = controller.resolutionText { Text("Sampling \(r)") }
                    }
                }
                Button("Cancel session", role: .destructive) {
                    controller.stop()
                    path.removeLast()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.7)))
            }
        }
    }

    // MARK: Instruction

    private var instruction: some View {
        VStack(spacing: 4) {
            Text(headline)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.ink)
                .contentTransition(.opacity)
            Text(detail)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: headline)
    }

    private var headline: String {
        switch controller.phase {
        case .idle, .starting: return "Preparing camera…"
        case .live: return controller.guidance.instruction.headline
        case .capturing: return "Captured."
        case .analyzing: return "Analysing…"
        case .captured: return "Captured."
        case .failed: return "Camera unavailable."
        }
    }

    private var detail: String {
        switch controller.phase {
        case .idle, .starting: return "Selecting the macro lens."
        case .live: return controller.guidance.instruction.detail
        case .capturing, .analyzing, .captured: return "Checking image quality."
        case .failed(let why): return why
        }
    }

    // MARK: Viewfinder

    private var viewfinder: some View {
        GeometryReader { geo in
            let mapper = FrameToViewMapper(viewSize: geo.size, frameAspect: controller.frameAspectRatio)
            ZStack {
                CameraPreviewView(frameSource: controller.frameSource)
                CaptureOverlay(
                    guidance: controller.guidance,
                    guide: controller.guide,
                    mapper: mapper,
                    eye: eye,
                    isBusy: controller.phase == .capturing || controller.phase == .analyzing
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Theme.Colors.ink.opacity(0.12), radius: 24, y: 12)
    }

    // MARK: Chips

    private var statusChips: some View {
        HStack(spacing: 12) {
            StatusChipLarge(
                text: controller.guidance.lightingReady ? "Lighting ready" : "Adjust lighting",
                systemImage: "sun.max",
                active: controller.guidance.lightingReady
            )
            StatusChipLarge(
                text: controller.guidance.eyeDetected ? "Eye detected" : "Finding eye",
                systemImage: controller.guidance.eyeDetected ? "checkmark.circle.fill" : "eye",
                active: controller.guidance.eyeDetected
            )
        }
    }

    private var autoCaptureCard: some View {
        Button { autoCapture.toggle() } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().strokeBorder(Theme.Colors.primary, lineWidth: 2).frame(width: 22, height: 22)
                    if autoCapture {
                        Circle().fill(Theme.Colors.primary).frame(width: 11, height: 11)
                    }
                }
                Text("Auto-capture when aligned")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.ink)
                Spacer()
                if !autoCapture {
                    Button("Capture") { controller.captureNow() }
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Theme.Colors.primary))
                        .disabled(controller.phase != .live)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Capsule().fill(Color.white.opacity(0.65)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var voiceRow: some View {
        Button { voiceEnabled.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                Text(voiceEnabled ? "Voice guidance on" : "Voice guidance off")
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Failure

    @ViewBuilder
    private var failureOverlay: some View {
        if case .failed(let message) = controller.phase {
            VStack(spacing: 14) {
                Image(systemName: "camera.badge.ellipsis")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.Colors.primary)
                Text("Capture unavailable")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.ink)
                Text(message)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await controller.start() } }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Back to session") { path.removeLast() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .glassCard()
            .screenPadding()
        }
    }
}

// MARK: - Overlay

struct CaptureOverlay: View {
    let guidance: Guidance
    let guide: GuideGeometry
    let mapper: FrameToViewMapper
    let eye: Eye
    let isBusy: Bool

    private var guideCenter: CGPoint { mapper.point(guide.center) }
    private var guideRadius: CGFloat { mapper.length(guide.targetIrisRadius) }
    private var ringColor: Color {
        guidance.positionReady ? Theme.Colors.guideMint : Theme.Colors.guideMint.opacity(0.85)
    }

    var body: some View {
        ZStack {
            // Darken outside the guide slightly to focus attention.
            Rectangle()
                .fill(Color.black.opacity(0.18))
                .mask(
                    Rectangle()
                        .overlay(
                            Circle()
                                .frame(width: guideRadius * 2.6, height: guideRadius * 2.6)
                                .position(guideCenter)
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )

            cornerBrackets

            // Target ring: dashed while positioning, solid + progress arc while stable.
            Circle()
                .strokeBorder(
                    ringColor,
                    style: StrokeStyle(lineWidth: 2.5, dash: guidance.positionReady ? [] : [6, 6])
                )
                .frame(width: guideRadius * 2, height: guideRadius * 2)
                .position(guideCenter)
                .animation(.easeInOut(duration: 0.2), value: guidance.positionReady)

            Circle()
                .trim(from: 0, to: guidance.alignmentProgress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: guideRadius * 2 + 14, height: guideRadius * 2 + 14)
                .position(guideCenter)
                .animation(.linear(duration: 0.1), value: guidance.alignmentProgress)

            // Live iris + pupil tracking.
            if let obs = guidance.observation {
                let c = mapper.point(obs.irisCenter)
                Circle()
                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1.2)
                    .frame(width: mapper.length(obs.irisRadius) * 2, height: mapper.length(obs.irisRadius) * 2)
                    .position(c)
                Circle()
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                    .frame(width: mapper.length(obs.pupilRadius) * 2, height: mapper.length(obs.pupilRadius) * 2)
                    .position(mapper.point(obs.pupilCenter))
            }

            VStack {
                HStack(spacing: 6) {
                    Image(systemName: "eye").font(.system(size: 12, weight: .semibold))
                    Text(eye.displayName).font(Theme.Typography.caption)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .padding(.top, 14)
                Spacer()
                if let arrow = guidance.instruction.arrowSymbol, let label = guidance.instruction.arrowLabel {
                    VStack(spacing: 4) {
                        Image(systemName: arrow).font(.system(size: 20, weight: .medium))
                        Text(label).font(Theme.Typography.caption)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .padding(.bottom, 18)
                } else if guidance.positionReady, guidance.alignmentProgress < 1 {
                    Text("Hold…")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                        .padding(.bottom, 18)
                }
            }

            if isBusy {
                Color.white.opacity(0.35)
                ProgressView().tint(Theme.Colors.primary).scaleEffect(1.3)
            }
        }
    }

    private var cornerBrackets: some View {
        GeometryReader { geo in
            let inset: CGFloat = 26
            let len: CGFloat = 26
            let w = geo.size.width, h = geo.size.height
            Path { p in
                // top-left
                p.move(to: CGPoint(x: inset, y: inset + len)); p.addLine(to: CGPoint(x: inset, y: inset)); p.addLine(to: CGPoint(x: inset + len, y: inset))
                // top-right
                p.move(to: CGPoint(x: w - inset - len, y: inset)); p.addLine(to: CGPoint(x: w - inset, y: inset)); p.addLine(to: CGPoint(x: w - inset, y: inset + len))
                // bottom-left
                p.move(to: CGPoint(x: inset, y: h - inset - len)); p.addLine(to: CGPoint(x: inset, y: h - inset)); p.addLine(to: CGPoint(x: inset + len, y: h - inset))
                // bottom-right
                p.move(to: CGPoint(x: w - inset - len, y: h - inset)); p.addLine(to: CGPoint(x: w - inset, y: h - inset)); p.addLine(to: CGPoint(x: w - inset, y: h - inset - len))
            }
            .stroke(Theme.Colors.guideMint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

struct StatusChipLarge: View {
    let text: String
    let systemImage: String
    let active: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? Theme.Colors.success : Theme.Colors.warning)
            Text(text)
                .font(Theme.Typography.caption)
                .foregroundStyle(active ? Theme.Colors.success : Theme.Colors.warning)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Capsule().fill(active ? Theme.Colors.successTint : Theme.Colors.warningTint))
        .animation(.easeInOut(duration: 0.2), value: active)
    }
}
