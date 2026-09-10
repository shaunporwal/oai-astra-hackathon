import Foundation

struct Pairing: Codable { let server_url: String; let pairing_token: String }
struct ConnectionStatus: Decodable { let astra_available: Bool }
struct AnalysisOptions: Codable { let target: String; let roi: [Double]? }
struct LocalMeasurement: Codable, Identifiable {
    let target_id: String; let name: String; let unit: String; let value: Double?; let status: String; let reason: String
    var id: String { target_id + ":" + name }
}
struct RednessOverlay: Decodable { let roi_xywh: [Double]?; let vessel_contours_xy: [[[Double]]] }
struct Ellipse: Decodable { let center_xy: [Double]; let axes_wh: [Double]; let angle_degrees: Double }
struct FrameAnalysis: Decodable {
    let image_size_wh: [Double]; let measurements: [LocalMeasurement]
    let redness: RednessOverlay; let pupil: Ellipse?; let iris: Ellipse?
}
struct Snapshot: Decodable { let case_id: String; let geometry: FrameAnalysis }
struct BackendEndpointMeasurement: Decodable { let name: String; let value: Double?; let status: String }
struct Endpoint: Decodable, Identifiable {
    let target_id: String; let name: String; let status: String; let observation: String; let limitations: [String]; let measurements: [BackendEndpointMeasurement]
    var id: String { target_id }
}
struct EndpointAssessment: Decodable { let targets: [Endpoint] }
struct Review: Decodable { let prediction: String; let endpoint_assessment: EndpointAssessment }

final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
struct AnalysisClient {
    let pairing: Pairing
    func connection() async throws -> ConnectionStatus {
        try JSONDecoder().decode(ConnectionStatus.self,from:await send(path:"api/connection",timeout:10))
    }
    private func send(path: String, jpeg: Data? = nil, options: AnalysisOptions? = nil, timeout: TimeInterval = 150) async throws -> Data {
        guard let base=URL(string: pairing.server_url), let scheme=base.scheme, ["http","https"].contains(scheme), base.host != nil,
              base.user == nil,base.password == nil,base.query == nil,base.fragment == nil,
              base.path.isEmpty || base.path == "/", !pairing.pairing_token.isEmpty else { throw ClientError.message("Paste a valid pairing configuration from your Mac.") }
        var request=URLRequest(url:base.appendingPathComponent(path))
        request.httpMethod="POST";request.timeoutInterval=timeout
        request.setValue(pairing.pairing_token,forHTTPHeaderField:"x-live-token")
        if let jpeg {
            request.httpBody=jpeg;request.setValue("image/jpeg",forHTTPHeaderField:"content-type")
            request.setValue("live_camera",forHTTPHeaderField:"x-source-mode")
        }
        if let options { request.setValue(String(data:try JSONEncoder().encode(options),encoding:.utf8),forHTTPHeaderField:"x-analysis-options") }
        let session=URLSession(configuration:.ephemeral,delegate:NoRedirects(),delegateQueue:nil)
        defer { session.finishTasksAndInvalidate() }
        let (data,response)=try await session.data(for:request)
        guard let response=response as? HTTPURLResponse else { throw ClientError.message("No server response") }
        guard response.statusCode == 200 else {
            let detail=(try? JSONSerialization.jsonObject(with:data) as? [String:Any])?["detail"] as? String
            throw ClientError.message(detail ?? "Server returned HTTP \(response.statusCode)")
        }
        return data
    }
    func snapshot(jpeg: Data, options: AnalysisOptions) async throws -> Snapshot {
        try JSONDecoder().decode(Snapshot.self,from:await send(path:"api/snapshot",jpeg:jpeg,options:options))
    }
    func review(caseID: String) async throws -> Review {
        try JSONDecoder().decode(Review.self,from:await send(path:"api/review/\(caseID)"))
    }
    enum ClientError: LocalizedError { case message(String); var errorDescription: String? { if case let .message(text)=self { return text };return nil } }
}
