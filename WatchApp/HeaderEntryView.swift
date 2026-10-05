import SwiftUI
import AuditModel

struct HeaderEntryView: View {
    @Environment(FloorSession.self) private var session
    let side: Side
    let onCommitted: () -> Void

    // Not seeded from the signed-in nurse. ANM/RHC is its own human entry;
    // the person holding the watch is not automatically the charge.
    @State private var anm = ""
    @State private var census = 0
    @State private var censusTouched = false
    @FocusState private var crownFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Date is the shift's calendar day. There is no date control.
            Text("\(session.shift.date) · \(session.shift.label)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 6) {
                Text("ANM/RHC")
                    .font(.caption2)
                Spacer(minLength: 0)
                ForEach(NurseProfile.all) { profile in
                    Button {
                        anm = profile.icon
                    } label: {
                        Text(profile.icon)
                            .font(profile.icon == "🦾" ? .body : .headline)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(anm == profile.icon ? Color.accentColor : Color.gray.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(profile.name)
                    .accessibilityIdentifier("anm.\(profile.token)")
                }
            }

            HStack(spacing: 6) {
                Text("CENSUS")
                    .font(.caption2)
                Spacer(minLength: 0)
                Text(censusTouched ? "\(census)" : "—")
                    .font(.title2)
                    .frame(minWidth: 36)
                    .focusable()
                    .focused($crownFocused)
                    .digitalCrownRotation(
                        detent: $census,
                        from: 0,
                        through: 26,
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true,
                        onChange: { _ in censusTouched = true }
                    )
                    .accessibilityIdentifier("census.value")
                NavigationLink {
                    CensusPicker(census: $census, touched: $censusTouched)
                } label: {
                    Text("Pick")
                        .font(.caption)
                }
                .accessibilityIdentifier("census.pick")
            }

            Button("Continue") {
                guard session.commitHeader(side: side, anmRHC: anm, census: census) else { return }
                onCommitted()
            }
            .buttonStyle(.borderedProminent)
            .disabled(anm.isEmpty || !censusTouched)
            .frame(maxWidth: .infinity, minHeight: 40)
            .accessibilityIdentifier("header.continue")
        }
        .navigationTitle(side.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { crownFocused = true }
    }
}

private struct CensusPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var census: Int
    @Binding var touched: Bool

    var body: some View {
        List(0...26, id: \.self) { value in
            Button("\(value)") {
                census = value
                touched = true
                dismiss()
            }
            .accessibilityIdentifier("census.\(value)")
        }
        .navigationTitle("Census")
        .navigationBarTitleDisplayMode(.inline)
    }
}
