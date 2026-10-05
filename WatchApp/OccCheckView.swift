import SwiftUI
import AuditModel

struct OccCheckView: View {
    @Environment(FloorSession.self) private var session
    let side: Side
    let room: String
    let onAnswered: (Bool) -> Void

    private var occupied: Bool? {
        if case .answered(.bool(let value)) = session.sheet(for: side)?.state(of: .occ, in: room) {
            return value
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("OCC.")
                .font(.title3)
            Text(room)
                .font(.largeTitle)
            Button("Yes") {
                session.answerOcc(side: side, room: room, occupied: true)
                onAnswered(true)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay(alignment: .trailing) {
                if occupied == true {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .padding(.trailing, 10)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityIdentifier("occ.yes")
            Button("No") {
                session.answerOcc(side: side, room: room, occupied: false)
                onAnswered(false)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay(alignment: .trailing) {
                if occupied == false {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .padding(.trailing, 10)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityIdentifier("occ.no")
        }
        .navigationTitle("OCC.")
        .navigationBarTitleDisplayMode(.inline)
    }
}
