import SwiftUI

struct ProfilePickerView: View {
    @Environment(FloorSession.self) private var session
    let onSelect: (NurseProfile) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(NurseProfile.all) { profile in
                Button {
                    onSelect(profile)
                } label: {
                    HStack(spacing: 8) {
                        Text(profile.icon)
                            .font(profile.icon == "🦾" ? .title3 : .headline)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(tint(profile).opacity(session.nurse == profile ? 0.85 : 0.35)))
                        Text(profile.name)
                            .font(.body)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityLabel(profile.name)
                .accessibilityIdentifier("profile.\(profile.token)")
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tint(_ profile: NurseProfile) -> Color {
        switch profile.icon {
        case "MB": .blue
        case "C": .teal
        default: .orange
        }
    }
}
