import SwiftUI
import AuditModel

/// Which room the dimmed face should show. Screens write it as the nurse moves.
@MainActor
@Observable
final class GlanceFocus {
    var side: Side?
    var room: String?
}

/// Wrist-down face. Black field, one room number, almost no light.
struct DimmedRoomFace: View {
    @Environment(\.isLuminanceReduced) private var dimmed
    @Environment(GlanceFocus.self) private var glance
    @Environment(FloorSession.self) private var session
    @Environment(LookTryOn.self) private var looks

    var body: some View {
        if dimmed {
            ZStack {
                Color.black
                VStack(spacing: 2) {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                    Text(hero)
                        .font(.system(size: 56, weight: .medium, design: .rounded))
                        .foregroundStyle(numberInk)
                        .minimumScaleFactor(0.35)
                        .lineLimit(1)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(hero)
        }
    }

    private var numberInk: Color {
        looks.current == .warm ? LookPalette.cream.opacity(0.8) : Color.white.opacity(0.72)
    }

    private var hero: String {
        if let room = glance.room { return room }
        if let side = glance.side { return side.title }
        return "Miss B"
    }

    private var caption: String {
        if glance.room != nil, let side = glance.side { return side.title }
        return session.shift.label
    }
}
