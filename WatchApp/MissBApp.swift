import SwiftUI

@main
struct MissBApp: App {
    @State private var session: FloorSession
    @State private var wrist = WristSession()
    @State private var glance = GlanceFocus()
    @State private var looks = LookTryOn()

    init() {
        _session = State(initialValue: FloorSession())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    LookSwitcher()
                }
                .armWristSession(wrist)
                .overlay { DimmedRoomFace() }
                // These wrap the bar and the dimmed face. Inside them, the
                // dimmed face is built with no room to show and the app
                // crashes on the first frame, which sends the watch home.
                .environment(session)
                .environment(glance)
                .environment(looks)
        }
    }
}
