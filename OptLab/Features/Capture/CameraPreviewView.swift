import SwiftUI
import UIKit

/// Hosts the frame source's preview layer and keeps it sized to the view.
struct CameraPreviewView: UIViewRepresentable {
    let frameSource: FrameSource

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.install(frameSource.makePreviewLayer())
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {}

    final class PreviewHostView: UIView {
        private var previewLayer: CALayer?

        func install(_ layer: CALayer) {
            previewLayer?.removeFromSuperlayer()
            previewLayer = layer
            layer.frame = bounds
            self.layer.addSublayer(layer)
            backgroundColor = .black
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer?.frame = bounds
            CATransaction.commit()
        }
    }
}

/// Maps frame-normalised coordinates (origin top-left, width = 1) to points inside a view
/// that shows the frame with aspect-fill.
struct FrameToViewMapper {
    let viewSize: CGSize
    /// Frame width / height.
    let frameAspect: Double

    private var scale: CGFloat {
        max(viewSize.width, viewSize.height * frameAspect)
    }
    private var displayedSize: CGSize {
        CGSize(width: scale, height: scale / frameAspect)
    }
    private var origin: CGPoint {
        CGPoint(x: (viewSize.width - displayedSize.width) / 2, y: (viewSize.height - displayedSize.height) / 2)
    }

    func point(_ normalized: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + normalized.x * displayedSize.width, y: origin.y + normalized.y * displayedSize.height)
    }

    /// Converts a radius expressed as a fraction of frame width.
    func length(_ fractionOfWidth: Double) -> CGFloat {
        fractionOfWidth * displayedSize.width
    }
}
