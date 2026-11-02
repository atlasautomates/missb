import SwiftUI

/// Prototype only. Two looks to compare on the wrist before one is kept.
/// The yellow bar is the switcher, not part of either design. The stored
/// value survives a relaunch so a shift can be charted in one look; delete
/// this type, the bar, and the losing branch once a look is picked.
enum AppLook: String {
    case clinical
    case warm

    var badge: String {
        switch self {
        case .clinical: "1  Clinical"
        case .warm: "2  Warm"
        }
    }

    var canvas: Color {
        switch self {
        case .clinical: .black
        case .warm: Color(red: 0.16, green: 0.09, blue: 0.07)
        }
    }

    var accent: Color {
        switch self {
        case .clinical: LookPalette.teal
        case .warm: LookPalette.coral
        }
    }
}

enum LookPalette {
    static let teal = Color(red: 0.45, green: 0.82, blue: 0.82)
    static let coral = Color(red: 0.93, green: 0.42, blue: 0.36)
    static let honey = Color(red: 0.98, green: 0.76, blue: 0.42)
    static let leaf = Color(red: 0.55, green: 0.82, blue: 0.58)
    static let cream = Color(red: 1.0, green: 0.96, blue: 0.90)
}

@MainActor
@Observable
final class LookTryOn {
    var current: AppLook

    private static let key = "missb.prototype.look"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key),
           let stored = AppLook(rawValue: raw) {
            current = stored
        } else {
            current = .clinical
        }
    }

    func cycle() {
        current = current == .clinical ? .warm : .clinical
        UserDefaults.standard.set(current.rawValue, forKey: Self.key)
    }
}

/// High-contrast pill. Sits on every screen so the two looks can be flipped
/// without backing out of a room.
struct LookSwitcher: View {
    @Environment(LookTryOn.self) private var looks

    var body: some View {
        Button {
            LightHaptic.play()
            looks.cycle()
        } label: {
            Text("Try-on   \(looks.current.badge)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.yellow))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.92))
        .accessibilityIdentifier("look.switch")
    }
}

private struct LookCanvas: ViewModifier {
    @Environment(LookTryOn.self) private var looks

    func body(content: Content) -> some View {
        content.background(looks.current.canvas.ignoresSafeArea())
    }
}

extension View {
    func lookCanvas() -> some View {
        modifier(LookCanvas())
    }
}
