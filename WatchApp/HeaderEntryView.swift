import SwiftUI
import AuditModel

struct HeaderEntryView: View {
    @Environment(FloorSession.self) private var session
    @Environment(GlanceFocus.self) private var glance
    @Environment(LookTryOn.self) private var looks
    let side: Side
    let onCommitted: () -> Void

    // Seeded from the signed-in nurse (ticket 014 feedback: picking a profile
    // lands its initials in ANM with no separate step). The preset buttons
    // below remain the tap-only override path.
    @State private var anm = ""
    @State private var census = 0
    @State private var censusTouched = false
    @FocusState private var crownFocused: Bool

    var body: some View {
        // Continue stays on screen. The fields can scroll; the button cannot
        // drop under the try-on bar, which is what left both looks stuck here.
        VStack(spacing: 4) {
            ScrollView {
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
                        // The custom-profile value is a full name, which no button
                        // mirrors — show the live value so autofill is visible.
                        Text(anm.isEmpty ? "—" : anm)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .foregroundStyle(anm.isEmpty ? Color.secondary : Color.primary)
                            .accessibilityIdentifier("anm.value")
                        Spacer(minLength: 0)
                        ForEach(NurseProfile.all) { profile in
                            Button {
                                LightHaptic.play()
                                anm = profile.anmValue
                            } label: {
                                Text(profile.icon)
                                    .font(profile.icon == "🦾" ? .body : .headline)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(anm == profile.anmValue ? looks.current.accent : Color.white.opacity(0.12)))
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
                            CensusPicker(census: $census) { censusTouched = true }
                        } label: {
                            Text("Pick")
                                .font(.caption)
                        }
                        .accessibilityIdentifier("census.pick")
                    }
                }
            }
            continueButton
        }
        .navigationTitle(side.title)
        .navigationBarTitleDisplayMode(.inline)
        .lookCanvas()
        .onAppear {
            glance.side = side
            glance.room = nil
            crownFocused = true
            // Autofill once; a value the nurse already overrode stays put.
            if anm.isEmpty, let nurse = session.nurse {
                anm = nurse.anmValue
            }
        }
    }

    /// Solid in both looks. Clinical used to be teal text with no fill, so on
    /// a full face it read as if the control was missing.
    private var continueButton: some View {
        let ready = !anm.isEmpty && censusTouched
        return Button {
            LightHaptic.play()
            guard session.commitHeader(side: side, anmRHC: anm, census: census) else { return }
            onCommitted()
        } label: {
            Text("Continue")
                .font(.body.weight(.semibold))
                .foregroundStyle(looks.current == .clinical ? Color.black : Color.white)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: looks.current == .warm ? 20 : 8, style: .continuous)
                        .fill(looks.current == .clinical ? LookPalette.teal : LookPalette.coral)
                )
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .opacity(ready ? 1 : 0.4)
        .accessibilityIdentifier("header.continue")
    }
}

struct CensusPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var census: Int
    var onPick: () -> Void = {}

    var body: some View {
        List(0...26, id: \.self) { value in
            Button("\(value)") {
                LightHaptic.play()
                census = value
                onPick()
                dismiss()
            }
            .accessibilityIdentifier("census.\(value)")
        }
        .navigationTitle("Census")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Starting census for a side that already has a header. Crown or the list
/// writes through; room charting is left alone. The corner countdown is this
/// number minus completed occupied rooms.
struct CensusEditView: View {
    @Environment(FloorSession.self) private var session
    let side: Side
    @State private var census: Int
    @FocusState private var crownFocused: Bool

    init(side: Side, starting: Int) {
        self.side = side
        _census = State(initialValue: starting)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Starting census")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(census)")
                .font(.largeTitle)
                .focusable()
                .focused($crownFocused)
                .digitalCrownRotation(
                    detent: $census,
                    from: 0,
                    through: 26,
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .accessibilityIdentifier("census.edit.value")
            NavigationLink {
                CensusPicker(census: $census)
            } label: {
                Text("Pick")
            }
            .accessibilityIdentifier("census.edit.pick")
        }
        .navigationTitle("Census")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { crownFocused = true }
        .onChange(of: census) { _, new in
            session.updateCensus(side: side, census: new)
        }
    }
}
