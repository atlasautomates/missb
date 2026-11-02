import SwiftUI
import AuditModel

struct OccCheckView: View {
    @Environment(FloorSession.self) private var session
    @Environment(GlanceFocus.self) private var glance
    @Environment(LookTryOn.self) private var looks
    let side: Side
    let room: String
    let onAnswered: (Bool) -> Void

    private var occupied: Bool? {
        if case .answered(.bool(let value)) = session.sheet(for: side)?.state(of: .occ, in: room) {
            return value
        }
        return nil
    }

    var body: some View {
        Group {
            switch looks.current {
            case .clinical:
                clinical
            case .warm:
                warm
            }
        }
        .navigationTitle("OCC.")
        .navigationBarTitleDisplayMode(.inline)
        .lookCanvas()
        .onAppear {
            glance.side = side
            glance.room = room
        }
    }

    /// The room number is the screen. Yes takes the accent. No stays quiet.
    private var clinical: some View {
        VStack(spacing: 6) {
            Text(room)
                .font(.system(size: 44, weight: .medium, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("Occupied")
                .font(.caption2)
                .foregroundStyle(.secondary)
            answer("Yes", occupied: true, filled: true, tint: LookPalette.teal, identifier: "occ.yes")
            answer("No", occupied: false, filled: false, tint: .white, identifier: "occ.no")
        }
    }

    /// Room sits in a circle. Yes and No are the same size, side by side.
    private var warm: some View {
        VStack(spacing: 8) {
            Text(room)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 84, height: 84)
                .background(Circle().fill(LookPalette.honey.opacity(0.28)))
            HStack(spacing: 8) {
                answer("Yes", occupied: true, filled: true, tint: LookPalette.leaf, identifier: "occ.yes")
                answer("No", occupied: false, filled: true, tint: LookPalette.coral, identifier: "occ.no")
            }
        }
    }

    private func answer(_ title: String, occupied value: Bool, filled: Bool, tint: Color, identifier: String) -> some View {
        Button {
            LightHaptic.play()
            session.answerOcc(side: side, room: room, occupied: value)
            onAnswered(value)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(looks.current == .warm ? .headline : .body.weight(.medium))
                if occupied == value {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(filled && looks.current == .clinical ? Color.black : (filled ? Color.white : Color.primary))
            .frame(maxWidth: .infinity, minHeight: looks.current == .warm ? 52 : 40)
            .background(
                RoundedRectangle(cornerRadius: looks.current == .warm ? 26 : 8, style: .continuous)
                    .fill(filled ? tint : Color.white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
