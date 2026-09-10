import Foundation
import CoreGraphics
import CoreImage
import UIKit

/// Procedurally rendered anterior segment used by the simulator frame source and by unit
/// tests that need ground-truth geometry.
enum SyntheticEyeRenderer {
    struct Scene {
        /// Iris centre in top-left normalised coordinates.
        var irisCenter = CGPoint(x: 0.5, y: 0.5)
        /// Iris radius as a fraction of frame width.
        var irisRadius = 0.19
        /// Pupil radius relative to iris radius.
        var pupilRatio = 0.36
        /// Gaussian blur radius in pixels (0 = tack sharp).
        var blur: Double = 0
        /// Global brightness multiplier.
        var exposure: Double = 1
        /// Adds a pale limbal ring when > 0.
        var arcus: Double = 0
        /// Redness of the sclera 0…1.
        var redness: Double = 0.15
        var irisColor = UIColor(red: 0.45, green: 0.27, blue: 0.12, alpha: 1)
    }

    static func render(size: CGSize, scene: Scene) -> CGImage {
        let w = size.width, h = size.height
        let renderer = UIGraphicsImageRenderer(size: size, format: {
            let f = UIGraphicsImageRendererFormat()
            f.scale = 1
            f.opaque = true
            return f
        }())
        let image = renderer.image { ctx in
            let g = ctx.cgContext
            let cx = scene.irisCenter.x * w
            let cy = scene.irisCenter.y * h
            let ri = scene.irisRadius * w
            let rp = ri * scene.pupilRatio

            // Skin.
            g.setFillColor(UIColor(red: 0.85, green: 0.66, blue: 0.55, alpha: 1).cgColor)
            g.fill(CGRect(origin: .zero, size: size))

            // Palpebral aperture (sclera) — almond shape.
            let eyeW = ri * 5.2, eyeH = ri * 2.9
            let aperture = UIBezierPath()
            aperture.move(to: CGPoint(x: cx - eyeW / 2, y: cy))
            aperture.addQuadCurve(to: CGPoint(x: cx + eyeW / 2, y: cy), controlPoint: CGPoint(x: cx, y: cy - eyeH))
            aperture.addQuadCurve(to: CGPoint(x: cx - eyeW / 2, y: cy), controlPoint: CGPoint(x: cx, y: cy + eyeH))
            aperture.close()
            g.saveGState()
            g.addPath(aperture.cgPath)
            g.clip()
            let scleraBase = UIColor(red: 0.97, green: 0.96 - 0.12 * scene.redness, blue: 0.95 - 0.14 * scene.redness, alpha: 1)
            g.setFillColor(scleraBase.cgColor)
            g.fill(CGRect(origin: .zero, size: size))

            // Conjunctival vessels.
            g.setStrokeColor(UIColor(red: 0.78, green: 0.25, blue: 0.25, alpha: 0.35 + 0.5 * scene.redness).cgColor)
            g.setLineWidth(max(ri * 0.02, 1))
            var rng = SeededGenerator(seed: 7)
            for _ in 0..<18 {
                let side: CGFloat = Bool.random(using: &rng) ? 1 : -1
                let startX = cx + side * (ri * 1.15 + CGFloat.random(in: 0...ri * 0.3, using: &rng))
                let y0 = cy + CGFloat.random(in: -ri * 0.7...ri * 0.7, using: &rng)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: startX, y: y0))
                var x = startX, y = y0
                for _ in 0..<4 {
                    x += side * ri * 0.3
                    y += CGFloat.random(in: -ri * 0.15...ri * 0.15, using: &rng)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                g.addPath(path.cgPath)
                g.strokePath()
            }

            // Iris with radial gradient and fibre texture.
            let irisRect = CGRect(x: cx - ri, y: cy - ri, width: 2 * ri, height: 2 * ri)
            let irisPath = UIBezierPath(ovalIn: irisRect)
            g.saveGState()
            g.addPath(irisPath.cgPath)
            g.clip()
            var rI: CGFloat = 0, gI: CGFloat = 0, bI: CGFloat = 0, aI: CGFloat = 0
            scene.irisColor.getRed(&rI, green: &gI, blue: &bI, alpha: &aI)
            let colors = [
                UIColor(red: rI * 1.25, green: gI * 1.25, blue: bI * 1.2, alpha: 1).cgColor,
                scene.irisColor.cgColor,
                UIColor(red: rI * 0.55, green: gI * 0.55, blue: bI * 0.6, alpha: 1).cgColor,
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.35, 0.8, 1])!
            g.drawRadialGradient(gradient, startCenter: CGPoint(x: cx, y: cy), startRadius: rp, endCenter: CGPoint(x: cx, y: cy), endRadius: ri, options: [])
            g.setStrokeColor(UIColor(white: 0, alpha: 0.18).cgColor)
            g.setLineWidth(max(ri * 0.012, 0.8))
            for i in 0..<72 {
                let theta = Double(i) / 72 * 2 * Double.pi
                let cosT = CGFloat(Foundation.cos(theta)), sinT = CGFloat(Foundation.sin(theta))
                let r0 = rp * 1.05, r1 = ri * (0.9 + 0.08 * CGFloat.random(in: 0...1, using: &rng))
                g.move(to: CGPoint(x: cx + r0 * cosT, y: cy + r0 * sinT))
                g.addLine(to: CGPoint(x: cx + r1 * cosT, y: cy + r1 * sinT))
            }
            g.strokePath()
            if scene.arcus > 0 {
                g.setStrokeColor(UIColor(white: 0.85, alpha: 0.55 * scene.arcus).cgColor)
                g.setLineWidth(ri * 0.12)
                g.strokeEllipse(in: irisRect.insetBy(dx: ri * 0.08, dy: ri * 0.08))
            }
            g.restoreGState()

            // Limbal shading.
            g.setStrokeColor(UIColor(white: 0.1, alpha: 0.35).cgColor)
            g.setLineWidth(max(ri * 0.04, 1))
            g.strokeEllipse(in: irisRect)

            // Pupil.
            g.setFillColor(UIColor(red: 0.03, green: 0.02, blue: 0.02, alpha: 1).cgColor)
            g.fillEllipse(in: CGRect(x: cx - rp, y: cy - rp, width: 2 * rp, height: 2 * rp))

            // Specular highlight (the phone's ring light reflection).
            g.setFillColor(UIColor(white: 1, alpha: 0.9).cgColor)
            g.fillEllipse(in: CGRect(x: cx - rp * 0.55, y: cy - rp * 0.75, width: rp * 0.35, height: rp * 0.3))

            g.restoreGState()

            // Lid margins and lashes.
            g.setStrokeColor(UIColor(red: 0.35, green: 0.2, blue: 0.15, alpha: 1).cgColor)
            g.setLineWidth(max(ri * 0.06, 1))
            g.addPath(aperture.cgPath)
            g.strokePath()
        }

        var cg = image.cgImage!
        if scene.blur > 0 || scene.exposure != 1 {
            var ci = CIImage(cgImage: cg)
            if scene.blur > 0 {
                ci = ci.clampedToExtent().applyingGaussianBlur(sigma: scene.blur).cropped(to: CGRect(origin: .zero, size: size))
            }
            if scene.exposure != 1 {
                ci = ci.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: log2(scene.exposure)])
            }
            cg = CIContext().createCGImage(ci, from: ci.extent) ?? cg
        }
        return cg
    }
}

/// Small deterministic PRNG so synthetic textures are stable across frames and tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
