import SwiftUI

extension String {
    /// Display label only. The stored choice stays the raw option string.
    var asCheckLabel: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

struct CheckTap<Label: View>: View {
    var selected: Bool
    var tint: Color = .accentColor
    var enabled: Bool = true
    var identifier: String
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 6)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? tint : Color.white.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityIdentifier(identifier)
    }
}

/// Shared chrome for every check so a later header-bar change has one seam.
struct CheckPage<Content: View>: View {
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
                Button(action: onBack) {
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
                CheckTap(selected: true, tint: .orange, identifier: "check.skip", action: onSkip) {
                    Text("Skip")
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier(identifier)
    }
}
