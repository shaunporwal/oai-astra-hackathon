import SwiftUI

@main
struct OptLabApp: App {
    @State private var store: SessionStore = {
        let store = SessionStore()
        // Used by UI tests and demos to start from the seeded schedule.
        if CommandLine.arguments.contains("--reset-demo") { store.resetForDemo() }
        return store
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}
