import SwiftUI
import AuditModel

struct RoomListView: View {
    @Environment(FloorSession.self) private var session
    let side: Side
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text(summary)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(side.rooms, id: \.self) { room in
                        Button {
                            onSelect(room)
                        } label: {
                            roomRow(room)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                        .accessibilityIdentifier("room.\(room)")
                    }
                }
                .scrollTargetLayout()
            }
            .modifier(RoomSnapModifier())
        }
        .navigationTitle(side.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: String {
        let sheet = session.sheet(for: side)
        let done = side.rooms.filter { sheet?.isRoomComplete($0) ?? false }.count
        let anm = sheet?.anmRHC ?? ""
        let census = sheet?.startingCensus.map(String.init) ?? "—"
        return "\(anm) · \(census) · \(done)/26"
    }

    private func roomRow(_ room: String) -> some View {
        let complete = session.sheet(for: side)?.isRoomComplete(room) ?? false
        return HStack(spacing: 4) {
            Text(room)
                .font(.title3)
            Spacer(minLength: 4)
            Text(complete ? "complete" : "incomplete")
                .font(.caption2)
                .foregroundStyle(complete ? Color.green : Color.secondary)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Room-by-room detent. A free flick would coast between rows; alwaysByOne
/// lands on the next room, which is the scroll-wheel snap the brief asked for.
private struct RoomSnapModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content.scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne, anchor: .top))
        } else if #available(watchOS 11.0, *) {
            content.scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        } else {
            content.scrollTargetBehavior(.viewAligned)
        }
    }
}
