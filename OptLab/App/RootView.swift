import SwiftUI

enum Route: Hashable {
    case session(UUID)
    case protocolDetail(UUID)
    /// `attempt` is a fresh token per push so that back-to-back captures (next eye, retake)
    /// never share view state even when they land at the same navigation depth.
    case capture(sessionID: UUID, eye: Eye, attempt: UUID = UUID())
    case qualityCheck(sessionID: UUID, capture: EyeCapture)
    case complete(UUID)
    case reviewImages(UUID)
    case endpoints(UUID)
}

/// Owns the navigation stack. Screens push routes; the capture flow pops back to the
/// session after each eye until the protocol is complete.
struct RootView: View {
    @Environment(SessionStore.self) private var store
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .navigationBarBackButtonHidden(false)
                        .toolbarBackground(.hidden, for: .navigationBar)
                }
        }
        .tint(Theme.Colors.primary)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .session(let id):
            if let session = store.session(id: id) {
                SessionView(session: session, path: $path)
            } else {
                missing
            }
        case .protocolDetail(let id):
            if let session = store.session(id: id) {
                ProtocolView(session: session)
            } else {
                missing
            }
        case .capture(let sessionID, let eye, let attempt):
            if let session = store.session(id: sessionID) {
                // Explicit identity: when one eye's capture is replaced by the next eye's at the
                // same stack depth, SwiftUI must not reuse the previous view's controller state.
                GuidedCaptureView(session: session, eye: eye, path: $path)
                    .id("capture-\(attempt.uuidString)")
            } else {
                missing
            }
        case .qualityCheck(let sessionID, let capture):
            if let session = store.session(id: sessionID) {
                QualityCheckView(session: session, capture: capture, path: $path)
                    .id("quality-\(capture.id.uuidString)")
            } else {
                missing
            }
        case .complete(let id):
            if let session = store.session(id: id) {
                CaptureCompleteView(session: session, path: $path)
            } else {
                missing
            }
        case .reviewImages(let id):
            if let session = store.session(id: id) {
                ReviewImagesView(session: session)
            } else {
                missing
            }
        case .endpoints(let id):
            if let session = store.session(id: id) {
                TrialEndpointsView(session: session)
            } else {
                missing
            }
        }
    }

    private var missing: some View {
        ZStack {
            AmbientBackground()
            Text("Session not found.").foregroundStyle(Theme.Colors.inkSecondary)
        }
    }
}
