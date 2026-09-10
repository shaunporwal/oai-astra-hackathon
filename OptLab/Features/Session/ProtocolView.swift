import SwiftUI

struct ProtocolView: View {
    let session: StudySession

    private var proto: ImagingProtocol { session.imagingProtocol }
    private var t: QualityThresholds { proto.thresholds }

    var body: some View {
        ZStack {
            AmbientBackground(warmth: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(proto.name)
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Colors.ink)
                        Text(proto.summary)
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 14) {
                        sectionTitle("Steps")
                        ForEach(Array(proto.steps.enumerated()), id: \.element.id) { i, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)")
                                    .font(Theme.Typography.caption)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(Color.white.opacity(0.8)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title).font(Theme.Typography.bodyMedium).foregroundStyle(Theme.Colors.ink)
                                    Text(step.detail).font(Theme.Typography.callout).foregroundStyle(Theme.Colors.inkSecondary)
                                }
                            }
                        }
                    }
                    .glassCard()

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Quality gate")
                        KeyValueRow(key: "Minimum sharpness", value: String(format: "%.2f", t.minSharpness))
                        KeyValueRow(key: "Exposure window", value: String(format: "%.2f – %.2f", t.exposureRange.lowerBound, t.exposureRange.upperBound))
                        KeyValueRow(key: "Max glare (clipped)", value: String(format: "%.0f %%", t.maxClipping * 100))
                        KeyValueRow(key: "Max drift per frame", value: String(format: "%.1f ‰ frame", t.maxMotion * 1000))
                        KeyValueRow(key: "Max device rotation", value: String(format: "%.2f rad/s", t.maxDeviceRotationRate))
                        KeyValueRow(key: "Iris size tolerance", value: String(format: "± %.0f %%", t.sizeTolerance * 100))
                        KeyValueRow(key: "Stable frames to capture", value: "\(t.requiredStableFrames)")
                    }
                    .glassCard()

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Scale reference")
                        Text("Millimetre values use the population-mean horizontal visible iris diameter (\(String(format: "%.2f", proto.referenceIrisDiameterMm)) mm ± \(String(format: "%.2f", ScaleCalibration.populationHVIDSDmm)) mm) as an in-image ruler. The resulting \(String(format: "%.1f", ScaleCalibration.populationHVIDSDmm / proto.referenceIrisDiameterMm * 100)) % scale uncertainty is propagated into every millimetre endpoint; ratio endpoints are scale-free.")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                    .glassCard()

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Endpoints")
                        ForEach(EndpointDomain.allCases) { domain in
                            let kinds = proto.endpoints.filter { $0.domain == domain }
                            if !kinds.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(domain.title, systemImage: domain.systemImage)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.primary)
                                    ForEach(kinds) { kind in
                                        Text("• \(kind.title)")
                                            .font(Theme.Typography.callout)
                                            .foregroundStyle(Theme.Colors.ink)
                                    }
                                }
                                .padding(.bottom, 6)
                            }
                        }
                    }
                    .glassCard()
                    ConceptFooter()
                }
                .screenPadding()
                .padding(.bottom, 24)
            }
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(Theme.Typography.overline)
            .foregroundStyle(Theme.Colors.inkSecondary)
            .kerning(1)
    }
}
