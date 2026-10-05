import SwiftUI
import AuditModel

struct SidePickerView: View {
    @Environment(FloorSession.self) private var session
    let onSelect: (Side) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(session.shift.date)
                .font(.headline)
            Text(session.shift.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            sideButton(.west)
            sideButton(.east)
        }
        .navigationTitle("Side")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sideButton(_ side: Side) -> some View {
        Button(side.title) {
            onSelect(side)
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityIdentifier("side.\(side.rawValue)")
    }
}
