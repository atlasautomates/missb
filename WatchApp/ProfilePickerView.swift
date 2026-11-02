import SwiftUI

struct ProfilePickerView: View {
    @Environment(FloorSession.self) private var session
    @Environment(GlanceFocus.self) private var glance
    @Environment(LookTryOn.self) private var looks
    let onSelect: (NurseProfile) -> Void

    var body: some View {
        // Four tiles no longer fit a 46mm face without scrolling.
        ScrollView {
            VStack(spacing: 8) {
                ForEach(NurseProfile.all) { profile in
                    Button {
                        LightHaptic.play()
                        onSelect(profile)
                    } label: {
                        tileLabel(icon: profile.icon, name: profile.name, tint: tint(profile), selected: session.nurse == profile)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityLabel(profile.name)
                    .accessibilityIdentifier("profile.\(profile.token)")
                }

                // The one sanctioned typing path on the watch (ticket 014):
                // TextFieldLink opens the system input sheet; the typed name
                // becomes the nurse identity and later the ANM value.
                TextFieldLink(prompt: Text("Name")) {
                    tileLabel(icon: "+", name: "Other", tint: .gray, selected: session.nurse?.isCustom == true)
                } onSubmit: { typed in
                    let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    LightHaptic.play()
                    onSelect(.custom(name: name))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityLabel("Other")
                .accessibilityIdentifier("profile.other")
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .lookCanvas()
        .onAppear {
            glance.side = nil
            glance.room = nil
        }
    }

    @ViewBuilder
    private func tileLabel(icon: String, name: String, tint: Color, selected: Bool) -> some View {
        if looks.current == .warm {
            HStack(spacing: 8) {
                Text(icon)
                    .font(icon == "🦾" ? .title3 : .headline)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(tint.opacity(selected ? 0.95 : 0.45)))
                Text(name)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.12 : 0.06))
            )
        } else {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(selected ? LookPalette.teal : Color.clear)
                    .frame(width: 3, height: 28)
                Text(icon)
                    .font(.caption.weight(.semibold))
                    .frame(width: 28, alignment: .leading)
                    .foregroundStyle(selected ? LookPalette.teal : Color.secondary)
                Text(name)
                    .font(.body)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .frame(minHeight: 44)
            .background(selected ? LookPalette.teal.opacity(0.12) : Color.white.opacity(0.04))
        }
    }

    private func tint(_ profile: NurseProfile) -> Color {
        switch profile.icon {
        case "MB": LookPalette.teal
        case "C": LookPalette.leaf
        default: LookPalette.honey
        }
    }
}
