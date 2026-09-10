import Foundation
import UIKit

/// Integration seam for the OptLab branch. Add this file and ios/shared/analysis_client.swift
/// to its target; call from a user-initiated action in ReviewImagesView.
/// This deliberately does not translate OptLab's local heuristic values into our endpoints.
@MainActor
struct OptLabAnalysisBridge {
    enum CaptureSource { case physicalCamera, simulation }
    struct LinkedResult {
        let optlabCaptureID: UUID
        let eye: Eye
        let backend: Snapshot
    }
    enum BridgeError: LocalizedError {
        case simulatedCapture, missingImage, encodingFailed
        var errorDescription: String? {
            switch self {
            case .simulatedCapture: return "Simulation must stay separate from physical-camera assessments."
            case .missingImage: return "The original OptLab capture could not be loaded."
            case .encodingFailed: return "The capture could not be converted to the backend JPEG format."
            }
        }
    }
    let client: AnalysisClient

    func analyze(capture: EyeCapture, source: CaptureSource, target: String, roi: [Double]?) async throws -> LinkedResult {
        guard source == .physicalCamera else { throw BridgeError.simulatedCapture }
        guard let image=ImageStore.load(fileName:capture.imageFileName) else { throw BridgeError.missingImage }
        let scale=min(1,960/max(image.size.width,image.size.height))
        let size=CGSize(width:max(1,round(image.size.width*scale)),height:max(1,round(image.size.height*scale)))
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        // Drawing normalizes UIImage orientation. The original full-resolution file is untouched.
        let normalized=UIGraphicsImageRenderer(size:size,format:format).image { _ in image.draw(in:CGRect(origin:.zero,size:size)) }
        guard let jpeg=normalized.jpegData(compressionQuality:0.92) else { throw BridgeError.encodingFailed }
        let backend=try await client.snapshot(jpeg:jpeg,options:AnalysisOptions(target:target,roi:roi))
        return LinkedResult(optlabCaptureID:capture.id,eye:capture.eye,backend:backend)
    }
    func review(_ result: LinkedResult) async throws -> Review {
        try await client.review(caseID:result.backend.case_id)
    }
}
