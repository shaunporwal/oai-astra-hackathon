import SwiftUI

struct TrialEndpointsView: View {
    @Environment(SessionStore.self) private var store
    let session: StudySession

    private var live: StudySession { store.session(id: session.id) ?? session }

    var body: some View {
        ZStack {
            AmbientBackground(warmth: 0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trial endpoints")
                                .font(Theme.Typography.title)
                                .foregroundStyle(Theme.Colors.ink)
                            Text("\(live.participant.displayName) · \(live.visitLabel)")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Colors.inkSecondary)
                        }
                        Spacer()
                        if let export = EndpointExport.make(for: live) {
                            ShareLink(item: export, preview: SharePreview("Endpoints \(live.participant.id) \(live.visitLabel)")) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.ink)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.white.opacity(0.7)))
                            }
                        }
                    }
                    .padding(.top, 8)

                    HStack {
                        Chip(text: "Pending review", tone: .warning, systemImage: "clock")
                        Chip(text: "Scale: anatomical HVID", tone: .info, systemImage: "ruler")
                    }

                    ForEach(EndpointDomain.allCases) { domain in
                        domainCard(domain)
                    }
                    methodsNote
                    ConceptFooter()
                }
                .screenPadding()
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func domainCard(_ domain: EndpointDomain) -> some View {
        let kinds = live.imagingProtocol.endpoints.filter { $0.domain == domain }
        let rows = kinds.compactMap { kind -> EndpointRowModel? in
            if kind.isSessionLevel {
                guard let m = live.sessionEndpoints.first(where: { $0.kind == kind }) else { return nil }
                return EndpointRowModel(kind: kind, od: nil, os: nil, session: m)
            }
            let od = live.capture(for: .right)?.endpoints.first { $0.kind == kind }
            let os = live.capture(for: .left)?.endpoints.first { $0.kind == kind }
            guard od != nil || os != nil else { return nil }
            return EndpointRowModel(kind: kind, od: od, os: os, session: nil)
        }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(domain.title, systemImage: domain.systemImage)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundStyle(Theme.Colors.ink)
                    Spacer()
                    if domain != .anatomy {
                        HStack(spacing: 0) {
                            Text("OD").frame(width: 64)
                            Text("OS").frame(width: 64)
                        }
                        .font(Theme.Typography.overline)
                        .foregroundStyle(Theme.Colors.inkTertiary)
                    }
                }
                ForEach(rows, id: \.kind) { row in
                    EndpointRow(model: row)
                }
            }
            .glassCard()
        }
    }

    private var methodsNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("METHODS")
                .font(Theme.Typography.overline)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .kerning(1)
            Text("Endpoints are computed on-device from the quality-passed still for each eye. Millimetre values use the population-mean horizontal visible iris diameter as an in-image ruler; the ± figures are 1-σ and include that scale uncertainty. Indices are unitless 0–100 chromaticity or contrast measures intended for within-participant change over visits. All values are investigational and pending reader review.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .glassCard()
    }
}

struct EndpointRowModel {
    var kind: EndpointKind
    var od: EndpointMeasurement?
    var os: EndpointMeasurement?
    var session: EndpointMeasurement?
}

private struct EndpointRow: View {
    let model: EndpointRowModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.kind.title)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.ink)
                    if !model.kind.unit.isEmpty {
                        Text(model.kind.unit)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.inkTertiary)
                    }
                }
                Spacer()
                if let s = model.session {
                    valueCell(s)
                } else {
                    HStack(spacing: 0) {
                        valueCell(model.od).frame(width: 64)
                        valueCell(model.os).frame(width: 64)
                    }
                }
            }
            if expanded {
                Text(model.kind.explanation)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }
    }

    @ViewBuilder
    private func valueCell(_ m: EndpointMeasurement?) -> some View {
        if let m {
            VStack(alignment: .trailing, spacing: 1) {
                Text(m.formattedValue)
                    .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.Colors.ink)
                if let u = m.formattedUncertainty {
                    Text(u).font(.system(size: 10)).foregroundStyle(Theme.Colors.inkTertiary)
                } else {
                    ConfidenceDots(confidence: m.confidence)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            Text("—").foregroundStyle(Theme.Colors.inkTertiary).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct ConfidenceDots: View {
    let confidence: Double
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Double(i) / 3 < confidence ? Theme.Colors.primary : Theme.Colors.ink.opacity(0.12))
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityLabel(String(format: "Confidence %.0f%%", confidence * 100))
    }
}

/// JSON export of a completed session's endpoints, suitable for EDC ingestion.
enum EndpointExport {
    struct Payload: Codable {
        var participantID: String
        var study: String
        var visit: Int
        var protocolID: String
        var exportedAt: Date
        var scaleMethod: String
        var captures: [CaptureRecord]
        var sessionEndpoints: [EndpointRecord]

        struct CaptureRecord: Codable {
            var eye: String
            var capturedAt: Date
            var device: String
            var imageWidth: Int?
            var imageHeight: Int?
            var mmPerPixel: Double?
            var quality: QualityReport
            var endpoints: [EndpointRecord]
        }

        struct EndpointRecord: Codable {
            var kind: String
            var title: String
            var value: Double
            var unit: String
            var uncertainty: Double?
            var confidence: Double
        }
    }

    static func make(for session: StudySession) -> URL? {
        func record(_ m: EndpointMeasurement) -> Payload.EndpointRecord {
            .init(kind: m.kind.rawValue, title: m.kind.title, value: m.value, unit: m.kind.unit, uncertainty: m.uncertainty, confidence: m.confidence)
        }
        let payload = Payload(
            participantID: session.participant.id,
            study: session.participant.studyName,
            visit: session.visitNumber,
            protocolID: session.imagingProtocol.id,
            exportedAt: .now,
            scaleMethod: "anatomical HVID \(ScaleCalibration.populationHVIDmm) mm",
            captures: session.imagingProtocol.eyes.compactMap { eye in
                guard let c = session.capture(for: eye) else { return nil }
                return .init(
                    eye: eye.rawValue, capturedAt: c.capturedAt, device: c.deviceModel,
                    imageWidth: c.geometry?.imageWidth, imageHeight: c.geometry?.imageHeight,
                    mmPerPixel: c.scale?.mmPerPixel, quality: c.quality, endpoints: c.endpoints.map(record)
                )
            },
            sessionEndpoints: session.sessionEndpoints.map(record)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("endpoints-\(session.participant.id)-v\(session.visitNumber).json")
        try? data.write(to: url, options: .atomic)
        return url
    }
}
