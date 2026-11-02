import SwiftUI
import AuditModel

struct SidePickerView: View {
    @Environment(FloorSession.self) private var session
    @Environment(GlanceFocus.self) private var glance
    @Environment(LookTryOn.self) private var looks
    let onSelect: (Side) -> Void
    @State private var confirmReset = false

    private var shiftStarted: Bool {
        session.sheet(for: .west) != nil || session.sheet(for: .east) != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(session.shift.date)
                    .font(.headline)
                Text(session.shift.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                sideButton(.west)
                sideButton(.east)
                Button {
                    LightHaptic.play()
                    confirmReset = true
                } label: {
                    Text("Reset shift")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!shiftStarted)
                .accessibilityIdentifier("shift.reset")
            }
        }
        .confirmationDialog(
            "Reset \(session.shift.label)? West and East charting will be cleared.",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Reset shift", role: .destructive) {
                LightHaptic.play()
                session.resetShift()
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationTitle("Side")
        .navigationBarTitleDisplayMode(.inline)
        .lookCanvas()
        .onAppear {
            glance.side = nil
            glance.room = nil
        }
    }

    private func sideButton(_ side: Side) -> some View {
        Button {
            LightHaptic.play()
            glance.side = side
            glance.room = nil
            onSelect(side)
        } label: {
            sideLabel(side)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("side.\(side.rawValue)")
    }

    @ViewBuilder
    private func sideLabel(_ side: Side) -> some View {
        if looks.current == .warm {
            Text(side.title)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LookPalette.coral.opacity(0.88))
                )
        } else {
            HStack {
                Text(side.title)
                    .font(.title3.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LookPalette.teal)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.white.opacity(0.06))
        }
    }
}
