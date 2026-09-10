import SwiftUI

struct CaptureCompleteView: View {
    @Environment(SessionStore.self) private var store
    let session: StudySession
    @Binding var path: [Route]

    private var live: StudySession { store.session(id: session.id) ?? session }

    var body: some View {
        ZStack {
            AmbientBackground()
            ScrollView {
                VStack(spacing: 18) {
                    Text("Eye imaging")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.ink)
                    ContextPill(segments: [live.participant.id, live.visitLabel, "Both eyes"])
                    VStack(spacing: 6) {
                        Text("Capture complete.")
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Colors.ink)
                        Text("Both eyes passed quality checks.")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }

                    summaryCard
                    connector
                    HStack(spacing: 14) {
                        NavTile(title: "Review images", systemImage: "photo") { path.append(.reviewImages(live.id)) }
                        NavTile(title: "Trial endpoints", systemImage: "chart.bar.xaxis") { path.append(.endpoints(live.id)) }
                    }

                    Button("Return to sessions") { path.removeAll() }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 8)
                    ConceptFooter()
                }
                .screenPadding()
                .padding(.vertical, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ForEach(live.imagingProtocol.eyes) { eye in
                    VStack(spacing: 8) {
                        CaptureThumbnail(capture: live.capture(for: eye))
                            .frame(height: 110)
                        Text(eye.displayName)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }
            }
            Text("\(live.visitLabel) imaging")
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.ink)
            Divider().overlay(Theme.Colors.divider)
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text").foregroundStyle(Theme.Colors.primary)
                    Text("Endpoint analysis").font(Theme.Typography.callout).foregroundStyle(Theme.Colors.ink)
                }
                Spacer()
                Chip(text: "Pending review", tone: .warning, systemImage: "clock")
            }
        }
        .glassCard()
    }

    private var connector: some View {
        // Small "branching" line between the summary card and the two tiles.
        Path { p in
            p.move(to: CGPoint(x: 0.5, y: 0)); p.addLine(to: CGPoint(x: 0.5, y: 0.5))
            p.move(to: CGPoint(x: 0.25, y: 1)); p.addLine(to: CGPoint(x: 0.25, y: 0.5)); p.addLine(to: CGPoint(x: 0.75, y: 0.5)); p.addLine(to: CGPoint(x: 0.75, y: 1))
        }
        .applying(CGAffineTransform(scaleX: 320, y: 28))
        .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .frame(width: 320, height: 28)
    }
}

struct CaptureThumbnail: View {
    let capture: EyeCapture?
    @State private var image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.Colors.lavender)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "eye").foregroundStyle(Theme.Colors.inkTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: capture?.id) {
            guard let capture else { return }
            let name = capture.imageFileName
            image = await Task.detached { ImageStore.load(fileName: name)?.preparingThumbnail(of: CGSize(width: 600, height: 800)) }.value
        }
    }
}

private struct NavTile: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    IconBubble(systemName: systemImage, size: 44)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.inkTertiary)
                }
                Text(title)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(padding: 16, radius: 22)
        }
        .buttonStyle(.plain)
    }
}
