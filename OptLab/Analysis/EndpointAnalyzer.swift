import Foundation
import CoreGraphics

/// Derives quantitative trial endpoints from a quality-passed anterior segment capture.
///
/// Scale: the population-mean horizontal visible iris diameter (HVID, 11.71 ± 0.42 mm) is
/// used as an in-image ruler, giving absolute millimetre measurements with a ~3.6 % 1-σ
/// scale uncertainty that is propagated into every millimetre endpoint. Ratio endpoints
/// (pupil/iris) are scale-free.
enum EndpointAnalyzer {
    struct Result {
        var geometry: EyeGeometry
        var scale: ScaleCalibration
        var endpoints: [EndpointMeasurement]
    }

    /// Angular half-width (degrees) of the nasal/temporal sectors used for scleral sampling.
    static let scleralSectorHalfAngle = 28.0

    /// - Parameters:
    ///   - image: Analysis-resolution RGBA raster of the full capture (e.g. 1024 px wide).
    ///   - fullResolutionSize: Pixel size of the persisted photo, for reporting geometry.
    ///   - hint: Live observation at capture time, used to seed the search window.
    static func analyze(
        image: RGBImage,
        fullResolutionSize: CGSize,
        hint: EyeObservation?,
        eye: Eye,
        pupilTraceMm: [Double],
        referenceHVIDmm: Double = ScaleCalibration.populationHVIDmm
    ) -> Result? {
        let gray = image.gray()
        let w = Double(image.width), h = Double(image.height)

        var search: CGRect? = nil
        if let hint {
            let r = max(hint.irisRadius * 2.2, 0.15)
            search = CGRect(
                x: (hint.irisCenter.x - r) * w, y: (hint.irisCenter.y - r * (w / h)) * h,
                width: 2 * r * w, height: 2 * r * w
            )
        }
        guard let fit = PupilLocalizer.localize(in: gray, searchRegion: search)
                ?? PupilLocalizer.localize(in: gray) else { return nil }

        // Geometry in full-resolution pixels.
        let upscale = Double(fullResolutionSize.width) / w
        let geometry = EyeGeometry(
            imageWidth: Int(fullResolutionSize.width),
            imageHeight: Int(fullResolutionSize.height),
            irisCenter: fit.irisCenter.scaled(by: upscale),
            irisRadiusPx: fit.irisRadius * upscale,
            pupilCenter: fit.pupilCenter.scaled(by: upscale),
            pupilRadiusPx: fit.pupilRadius * upscale,
            pupilCircularity: fit.pupilCircularity
        )
        let scale = ScaleCalibration(irisDiameterPx: geometry.irisDiameterPx, referenceHVIDmm: referenceHVIDmm)

        var endpoints: [EndpointMeasurement] = []
        let base = fit.confidence.clamped(to: 0.2...1)

        // --- Anatomy
        endpoints.append(EndpointMeasurement(
            kind: .irisDiameter, value: referenceHVIDmm,
            uncertainty: ScaleCalibration.populationHVIDSDmm, confidence: base, eye: eye
        ))

        // --- Neuro
        let pupilMm = scale.mm(fromPixels: geometry.pupilDiameterPx)
        endpoints.append(EndpointMeasurement(
            kind: .pupilDiameter, value: pupilMm,
            uncertainty: pupilMm * scale.relativeUncertainty, confidence: base, eye: eye
        ))
        endpoints.append(EndpointMeasurement(
            kind: .pupilIrisRatio, value: fit.pupilRadius / max(fit.irisRadius, 1e-6),
            uncertainty: nil, confidence: base, eye: eye
        ))
        endpoints.append(EndpointMeasurement(
            kind: .pupilCircularity, value: fit.pupilCircularity,
            uncertainty: nil, confidence: base, eye: eye
        ))
        if pupilTraceMm.count >= 5, pupilTraceMm.mean > 0 {
            let cv = pupilTraceMm.standardDeviation / pupilTraceMm.mean * 100
            endpoints.append(EndpointMeasurement(
                kind: .pupilVariability, value: cv, uncertainty: nil,
                confidence: min(1, Double(pupilTraceMm.count) / 30) * base, eye: eye
            ))
        }

        // --- Sclera-based endpoints
        let sclera = scleralSamples(in: image, gray: gray, fit: fit)
        if sclera.count >= 40 {
            let redness = sclera.map { rednessChroma($0) }
            let rednessIndex = (redness.mean * 300).clamped(to: 0...100)
            let vesselThreshold = redness.percentile(0.5) + 0.035
            let vesselFraction = Double(redness.filter { $0 > vesselThreshold }.count) / Double(redness.count) * 100
            let yellow = sclera.map { yellownessChroma($0) }
            let yellowIndex = (yellow.mean * 300).clamped(to: 0...100)
            let scleraConfidence = base * min(1, Double(sclera.count) / 400)

            endpoints.append(EndpointMeasurement(kind: .conjunctivalRedness, value: rednessIndex, uncertainty: nil, confidence: scleraConfidence, eye: eye))
            endpoints.append(EndpointMeasurement(kind: .scleralVesselDensity, value: vesselFraction, uncertainty: nil, confidence: scleraConfidence, eye: eye))
            endpoints.append(EndpointMeasurement(kind: .scleralYellowness, value: yellowIndex, uncertainty: nil, confidence: scleraConfidence, eye: eye))
        }

        // --- Metabolic: limbal arcus
        if let arcus = limbalArcusIndex(gray: gray, fit: fit) {
            endpoints.append(EndpointMeasurement(kind: .limbalArcusIndex, value: arcus, uncertainty: nil, confidence: base, eye: eye))
        }

        return Result(geometry: geometry, scale: scale, endpoints: endpoints)
    }

    /// Endpoints that need both eyes.
    static func sessionEndpoints(for session: StudySession) -> [EndpointMeasurement] {
        guard let od = session.capture(for: .right)?.endpoints.first(where: { $0.kind == .pupilDiameter }),
              let os = session.capture(for: .left)?.endpoints.first(where: { $0.kind == .pupilDiameter }) else {
            return []
        }
        let u = ((od.uncertainty ?? 0) * (od.uncertainty ?? 0) + (os.uncertainty ?? 0) * (os.uncertainty ?? 0)).squareRoot()
        return [
            EndpointMeasurement(
                kind: .anisocoria, value: od.value - os.value, uncertainty: u,
                confidence: min(od.confidence, os.confidence), eye: nil
            ),
        ]
    }

    // MARK: - Region sampling

    typealias RGB = (r: Double, g: Double, b: Double)

    /// Samples the exposed bulbar conjunctiva: an annulus outside the limbus restricted to the
    /// nasal and temporal sectors (clear of the eyelids), keeping bright, low-saturation pixels.
    static func scleralSamples(in image: RGBImage, gray: GrayImage, fit: EyeLocalization) -> [RGB] {
        let ri = fit.irisRadius
        let inner = ri * 1.12, outer = ri * 2.3
        let cx = Double(fit.irisCenter.x), cy = Double(fit.irisCenter.y)
        let halfAngle = scleralSectorHalfAngle * .pi / 180
        var out: [RGB] = []

        let x0 = max(Int(cx - outer), 0), x1 = min(Int(cx + outer), image.width - 1)
        let y0 = max(Int(cy - outer * sin(halfAngle)) - 1, 0), y1 = min(Int(cy + outer * sin(halfAngle)) + 1, image.height - 1)
        guard x0 < x1, y0 < y1 else { return [] }

        for y in y0...y1 {
            for x in x0...x1 {
                let dx = Double(x) - cx, dy = Double(y) - cy
                let d = hypot(dx, dy)
                guard d >= inner, d <= outer else { continue }
                let angle = abs(atan2(dy, dx))
                // Sector test: within ±halfAngle of 0° or 180°.
                guard angle <= halfAngle || angle >= .pi - halfAngle else { continue }
                let p = image.rgb(x: x, y: y)
                let luma = Double(gray[x, y]) / 255
                let maxC = max(p.r, p.g, p.b), minC = min(p.r, p.g, p.b)
                let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
                // Sclera is bright and weakly saturated; this rejects lashes, skin and iris.
                guard luma > 0.38, saturation < 0.55 else { continue }
                out.append(p)
            }
        }
        return out
    }

    /// (R − G) share of the total — 0 for neutral white, ≈0.33 for a saturated vessel.
    static func rednessChroma(_ p: RGB) -> Double {
        let sum = p.r + p.g + p.b
        guard sum > 0 else { return 0 }
        return max(0, p.r - p.g) / sum
    }

    /// Blue deficit relative to red/green — 0 for neutral white.
    static func yellownessChroma(_ p: RGB) -> Double {
        let sum = p.r + p.g + p.b
        guard sum > 0 else { return 0 }
        return max(0, (p.r + p.g) / 2 - p.b) / sum
    }

    /// Brightness of the peripheral corneal ring relative to the mid-iris. A pale limbal
    /// ring (arcus) pushes the ratio above 1; index = clamp((ratio − 1) × 200, 0, 100).
    static func limbalArcusIndex(gray: GrayImage, fit: EyeLocalization) -> Double? {
        let ri = fit.irisRadius
        guard ri > 6 else { return nil }
        let cx = Double(fit.irisCenter.x), cy = Double(fit.irisCenter.y)
        let halfAngle = 35.0 * .pi / 180

        func meanInAnnulus(_ a: Double, _ b: Double) -> Double? {
            var values: [Double] = []
            var r = a
            while r <= b {
                var theta = -halfAngle
                while theta <= halfAngle {
                    for base in [0.0, Double.pi] {
                        if let v = gray.sample(x: cx + r * cos(base + theta), y: cy + r * sin(base + theta)) {
                            values.append(v)
                        }
                    }
                    theta += 0.05
                }
                r += 1
            }
            return values.count > 10 ? values.mean : nil
        }

        guard let limbus = meanInAnnulus(ri * 0.82, ri * 0.97),
              let midIris = meanInAnnulus(ri * 0.45, ri * 0.70), midIris > 1 else { return nil }
        let ratio = limbus / midIris
        return ((ratio - 1) * 200).clamped(to: 0...100)
    }
}
