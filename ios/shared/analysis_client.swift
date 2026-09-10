import Foundation

struct Pairing: Codable { let server_url: String; let pairing_token: String }
struct ReviewJob: Codable { let status: String;let result: Review?;let detail: String? }
struct ConnectionStatus: Codable { let astra_available: Bool }
struct AnalysisOptions: Codable { let target: String; let roi: [Double]? }
struct LocalMeasurement: Codable, Identifiable {
    let target_id: String; let name: String; let unit: String; let value: Double?; let status: String; let reason: String
    var id: String { target_id + ":" + name }
}
struct RednessOverlay: Codable { let roi_xywh: [Double]?; let vessel_contours_xy: [[[Double]]] }
struct Ellipse: Codable { let center_xy: [Double]; let axes_wh: [Double]; let angle_degrees: Double }
struct FrameAnalysis: Codable {
    let image_size_wh: [Double]; let measurements: [LocalMeasurement]
    let redness: RednessOverlay; let pupil: Ellipse?; let iris: Ellipse?
}
struct Snapshot: Codable { let case_id: String; let geometry: FrameAnalysis }
struct BackendEndpointMeasurement: Codable { let name: String; let value: Double?; let status: String }
struct Endpoint: Codable, Identifiable {
    let target_id: String; let name: String; let status: String; let observation: String; let limitations: [String]; let measurements: [BackendEndpointMeasurement]
    var id: String { target_id }
}
struct EndpointAssessment: Codable { let targets: [Endpoint] }
struct ImageClaim: Codable {
    let claim: String; let location: String; let evidence_frame_indices: [Int]; let visual_confidence: String
    let interpretation: String; let alternative: String; let supporting_evidence: String
    let contradicting_or_missing_evidence: String; let verification: String
}
struct ImageAssessment: Codable { let headline: String; let summary: String; let claims: [ImageClaim] }
struct Review: Codable { let prediction: String; let endpoint_assessment: EndpointAssessment; var image_assessment: ImageAssessment? = nil }

final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
struct AnalysisClient {
    let pairing: Pairing
    func connection() async throws -> ConnectionStatus {
        try JSONDecoder().decode(ConnectionStatus.self,from:await send(path:"api/connection",timeout:10))
    }
    private func send(path: String, jpeg: Data? = nil, options: AnalysisOptions? = nil, timeout: TimeInterval = 150, sourceMode: String = "live_camera", method: String = "POST") async throws -> Data {
        guard let base=URL(string: pairing.server_url), let scheme=base.scheme, ["http","https"].contains(scheme), base.host != nil,
              base.user == nil,base.password == nil,base.query == nil,base.fragment == nil,
              base.path.isEmpty || base.path == "/", !pairing.pairing_token.isEmpty else { throw ClientError.message("Paste a valid pairing configuration from your Mac.") }
        var request=URLRequest(url:base.appendingPathComponent(path))
        request.httpMethod=method;request.timeoutInterval=timeout
        request.setValue(pairing.pairing_token,forHTTPHeaderField:"x-live-token")
        if let jpeg {
            request.httpBody=jpeg;request.setValue("image/jpeg",forHTTPHeaderField:"content-type")
            request.setValue(sourceMode,forHTTPHeaderField:"x-source-mode")
        }
        if let options { request.setValue(String(data:try JSONEncoder().encode(options),encoding:.utf8),forHTTPHeaderField:"x-analysis-options") }
        let configuration=URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest=timeout;configuration.timeoutIntervalForResource=timeout+15
        let session=URLSession(configuration:configuration,delegate:NoRedirects(),delegateQueue:nil)
        defer { session.finishTasksAndInvalidate() }
        let (data,response)=try await session.data(for:request)
        guard let response=response as? HTTPURLResponse else { throw ClientError.message("No server response") }
        guard response.statusCode == 200 else {
            let detail=(try? JSONSerialization.jsonObject(with:data) as? [String:Any])?["detail"] as? String
            throw ClientError.http(response.statusCode,detail ?? "Server returned HTTP \(response.statusCode)")
        }
        return data
    }
    func snapshot(jpeg: Data, options: AnalysisOptions, sourceMode: String = "live_camera") async throws -> Snapshot {
        try JSONDecoder().decode(Snapshot.self,from:await send(path:"api/snapshot",jpeg:jpeg,options:options,sourceMode:sourceMode))
    }
    func reviewStatus(caseID: String) async throws -> ReviewJob {
        try JSONDecoder().decode(ReviewJob.self,from:await send(path:"api/review-job/\(caseID)",timeout:15,method:"GET"))
    }
    func review(caseID: String) async throws -> Review {
        var state=try await reviewStatus(caseID:caseID)
        if let result=state.result { return result }
        if state.status != "running" {
            state=try JSONDecoder().decode(ReviewJob.self,from:await send(path:"api/review-job/\(caseID)",timeout:15))
        }
        for _ in 0..<120 {
            if let result=state.result { return result }
            if ["failed","interrupted"].contains(state.status) { throw ClientError.message(state.detail ?? "Astra review failed") }
            try await Task.sleep(for:.seconds(2))
            state=try await reviewStatus(caseID:caseID)
        }
        throw ClientError.message("The Mac may still be processing. Reopen this review to check its saved result; no automatic resubmission was made.")
    }
    enum ClientError: LocalizedError {
        case message(String), http(Int,String)
        var errorDescription: String? {
            switch self { case .message(let text), .http(_,let text): return text }
        }
    }
}
