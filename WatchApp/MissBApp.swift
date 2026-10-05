import SwiftUI

@main
struct MissBApp: App {
    @State private var session: FloorSession

    init() {
        _session = State(initialValue: FloorSession())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
    }
}
