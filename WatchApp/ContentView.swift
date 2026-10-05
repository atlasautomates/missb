import SwiftUI
import AuditModel

enum AppRoute: Hashable {
    case sides
    case header(Side)
    case rooms(Side)
    case occ(Side, String)
    case checks(Side, String)
}

struct ContentView: View {
    @Environment(FloorSession.self) private var session
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ProfilePickerView { profile in
                session.select(nurse: profile)
                path = [.sides]
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(route)
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .sides:
            SidePickerView { side in
                if session.needsHeader(side) {
                    path.append(.header(side))
                } else {
                    path.append(.rooms(side))
                }
            }
        case .header(let side):
            HeaderEntryView(side: side) {
                path.removeLast()
                path.append(.rooms(side))
            }
        case .rooms(let side):
            RoomListView(side: side) { room in
                path.append(.occ(side, room))
            }
        case .occ(let side, let room):
            OccCheckView(side: side, room: room) { occupied in
                path.removeLast()
                if occupied {
                    path.append(.checks(side, room))
                }
            }
        case .checks(let side, let room):
            CheckFlowView(side: side, room: room)
        }
    }
}
