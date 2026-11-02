import SwiftUI
import WatchKit

/// Keeps Miss B in front when the nurse lowers their wrist.
///
/// A normal watch app returns to the clock face on wrist-down. A self-care
/// runtime session leaves the app up and lets the screen dim. The system
/// grants that in stretches and can refuse another. Crown-press and switching
/// apps still leave, on purpose. The next time Miss B is frontmost, it asks again.
@MainActor
final class WristSession: NSObject, WKExtendedRuntimeSessionDelegate {
    private var runtime: WKExtendedRuntimeSession?
    private var refused = false

    func sceneBecameActive() {
        refused = false
        arm()
    }

    private func arm() {
        guard !refused else { return }
        if let runtime, runtime.state == .running || runtime.state == .scheduled {
            return
        }
        let next = WKExtendedRuntimeSession()
        next.delegate = self
        runtime = next
        next.start()
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        Task { @MainActor in
            self.runtime = nil
            switch reason {
            case .expired:
                self.arm()
            case .suppressedBySystem, .error:
                self.refused = true
            default:
                break
            }
        }
    }
}

private struct WristArm: View {
    @Environment(\.scenePhase) private var scenePhase
    let session: WristSession

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { session.sceneBecameActive() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    session.sceneBecameActive()
                }
            }
    }
}

extension View {
    func armWristSession(_ session: WristSession) -> some View {
        background { WristArm(session: session) }
    }
}
