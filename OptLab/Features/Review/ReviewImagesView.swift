import SwiftUI

struct ReviewImagesView: View {
    @Environment(SessionStore.self) private var store
    let session: StudySession
    @State private var selectedEye: Eye = .right
    @State private var showOverlay = true

    private var live: StudySession { store.session(id: session.id) ?? session }
    private var capture: EyeCapture? { live.capture(for: selectedEye) }

    var body: some View {
        ZStack {
            AmbientBackground(warmth: 0.4)
            ScrollView {
                VStack(spacing: 16) {
                    Text("Review images")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.ink)
                    Picker("Eye", selection: $selectedEye) {
                        ForEach(live.imagingProtocol.eyes) { eye in
                            Text(eye.displayName).tag(eye)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let capture {
                        AnnotatedCaptureView(capture: capture, showOverlay: showOverlay)
                            .aspectRatio(3 / 4, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                            .shadow(color: Theme.Colors.ink.opacity(0.12), radius: 24, y: 12)
                        Toggle("Show measurement overlay", isOn: $showOverlay)
                            .font(Theme.Typography.callout)
                            .tint(Theme.Colors.primary)
                            .padding(.horizontal, 4)
                        geometryCard(capture)
                        qualityCard(capture)
                    } else {
                        Text("No passed capture for this eye yet.")
                            .foregroundStyle(Theme.Colors.inkSecondary)
                            .glassCard()
                    }
                    ConceptFooter()
                }
                .screenPadding()
                .padding(.vertical, 8)
            }
        }
        .onAppear { selectedEye = live.imagingProtocol.eyes.first ?? .right }
    }

    private func geometryCard(_ c: EyeCapture) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GEOMETRY & SCALE")
                .font(Theme.Typography.overline)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .kerning(1)
            if let g = c.geometry, let s = c.scale {
                KeyValueRow(key: "Image", value: "\(g.imageWidth) × \(g.imageHeight) px")
                KeyValueRow(key: "Iris diameter", value: String(format: "%.0f px", g.irisDiameterPx))
                KeyValueRow(key: "Pupil diameter", value: String(format: "%.0f px · %.2f mm", g.pupilDiameterPx, s.mm(fromPixels: g.pupilDiameterPx)))
                KeyValueRow(key: "Sampling", value: String(format: "%.1f µm / px", s.mmPerPixel * 1000))
                KeyValueRow(key: "Scale method", value: "Anatomical HVID")
                KeyValueRow(key: "Scale uncertainty", value: String(format: "± %.1f %%", s.relativeUncertainty * 100))
                if let lens = c.lensPosition {
                    KeyValueRow(key: "Lens position", value: String(format: "%.2f", lens))
                }
                KeyValueRow(key: "Device", value: c.deviceModel)
            } else {
                Text("Geometry unavailable for this capture.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
        }
        .glassCard()
    }

    private func qualityCard(_ c: EyeCapture) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUALITY GATE")
                .font(Theme.Typography.overline)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .kerning(1)
            qualityRow("Focus", c.quality.focus)
            qualityRow("Coverage", c.quality.coverage)
            qualityRow("Exposure", c.quality.exposure)
            qualityRow("Motion", c.quality.motion)
        }
        .glassCard()
    }

    private func qualityRow(_ name: String, _ q: QualityCheck) -> some View {
        HStack(alignment: .top) {
            Text(name).foregroundStyle(Theme.Colors.inkSecondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(q.passed ? "Passed" : "Failed").foregroundStyle(q.passed ? Theme.Colors.success : Theme.Colors.danger).fontWeight(.medium)
                Text(q.detail).font(.system(size: 12)).foregroundStyle(Theme.Colors.inkTertiary)
            }
        }
        .font(Theme.Typography.callout)
    }
}

/// Full capture with iris/pupil fit and a 1 mm scale bar drawn in image space.
struct AnnotatedCaptureView: View {
    let capture: EyeCapture
    let showOverlay: Bool
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    if showOverlay, let g = capture.geometry, let s = capture.scale {
                        overlay(geometry: g, scale: s, imageSize: image.size, viewSize: geo.size)
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .task(id: capture.id) {
            let name = capture.imageFileName
            image = await Task.detached { ImageStore.load(fileName: name)?.preparingThumbnail(of: CGSize(width: 1500, height: 2000)) }.value
        }
    }

    private func overlay(geometry g: EyeGeometry, scale s: ScaleCalibration, imageSize: CGSize, viewSize: CGSize) -> some View {
        // Aspect-fit mapping from full-resolution pixels to view points.
        let fit = min(viewSize.width / CGFloat(g.imageWidth), viewSize.height / CGFloat(g.imageHeight))
        let drawn = CGSize(width: CGFloat(g.imageWidth) * fit, height: CGFloat(g.imageHeight) * fit)
        let origin = CGPoint(x: (viewSize.width - drawn.width) / 2, y: (viewSize.height - drawn.height) / 2)
        func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * fit, y: origin.y + p.y * fit) }
        let irisR = g.irisRadiusPx * fit
        let pupilR = g.pupilRadiusPx * fit
        let mmBar = fit / s.mmPerPixel  // points per millimetre

        return ZStack {
            Circle().strokeBorder(Theme.Colors.guideMint, lineWidth: 1.5)
                .frame(width: irisR * 2, height: irisR * 2).position(pt(g.irisCenter))
            Circle().strokeBorder(Color.white, lineWidth: 1.5)
                .frame(width: pupilR * 2, height: pupilR * 2).position(pt(g.pupilCenter))
            Path { p in
                let c = pt(g.pupilCenter)
                p.move(to: CGPoint(x: c.x - 6, y: c.y)); p.addLine(to: CGPoint(x: c.x + 6, y: c.y))
                p.move(to: CGPoint(x: c.x, y: c.y - 6)); p.addLine(to: CGPoint(x: c.x, y: c.y + 6))
            }
            .stroke(Color.white, lineWidth: 1)
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle().fill(Color.white).frame(width: mmBar, height: 3)
                        Text("1 mm").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.45)))
                    Spacer()
                    Text(String(format: "Ø pupil %.2f mm", s.mm(fromPixels: g.pupilDiameterPx)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.45)))
                }
                .padding(14)
            }
        }
    }
}
