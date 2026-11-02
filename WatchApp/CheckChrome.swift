import SwiftUI

extension String {
    /// Display label only. The stored choice stays the raw option string.
    var asCheckLabel: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

struct CheckTap<Label: View>: View {
    @Environment(LookTryOn.self) private var looks
    var selected: Bool
    var tint: Color = LookPalette.coral
    var enabled: Bool = true
    var identifier: String
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: {
            LightHaptic.play()
            action()
        }) {
            label()
                .font(looks.current == .warm ? .headline : .body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: looks.current == .warm ? 46 : 40)
                .padding(.horizontal, 8)
                .foregroundStyle(ink)
                .background(
                    RoundedRectangle(cornerRadius: looks.current == .warm ? 23 : 8, style: .continuous)
                        .fill(selected ? fill : Color.white.opacity(looks.current == .warm ? 0.10 : 0.07))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityIdentifier(identifier)
    }

    /// Clinical puts black type on the light teal. Warm keeps white on the tint.
    private var ink: Color {
        guard selected else { return .primary }
        return looks.current == .clinical ? .black : .white
    }

    private var fill: Color {
        looks.current == .clinical ? LookPalette.teal : tint
    }
}

/// Shared chrome for every check so a later header-bar change has one seam.
struct CheckPage<Content: View>: View {
    @Environment(LookTryOn.self) private var looks
    let title: String
    let identifier: String
    var onSkip: (() -> Void)?
    let onBack: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        core
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // The flow is one navigation destination for the whole room, so
            // the system back button would skip every earlier check. The
            // header walks paper order, and the bar stays hidden so that
            // system button cannot also appear.
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
    }

    private var core: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Button(action: {
                    LightHaptic.play()
                    onBack()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.backward")
                        Text("Back")
                    }
                    .font(.caption)
                    .frame(minHeight: 28)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("check.back")
                Spacer(minLength: 4)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            content()
                .frame(maxHeight: .infinity)
            // In the column, not over the options. A bottom safe-area inset
            // on watchOS drew Skip on top of the choice list.
            if let onSkip {
                CheckTap(
                    selected: looks.current == .warm,
                    tint: looks.current == .warm ? LookPalette.honey : Color.white.opacity(0.16),
                    identifier: "check.skip",
                    action: onSkip
                ) {
                    Text("Skip")
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .lookCanvas()
        .accessibilityIdentifier(identifier)
    }
}
