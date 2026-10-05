import SwiftUI
import AuditModel

struct OccCheckView: View {
    @Environment(FloorSession.self) private var session
    let side: Side
    let room: String
    let onAnswered: (Bool) -> Void

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
            .accessibilityIdentifier("occ.yes")
            Button("No") {
                session.answerOcc(side: side, room: room, occupied: false)
                onAnswered(false)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier("occ.no")
        }
        .navigationTitle("OCC.")
        .navigationBarTitleDisplayMode(.inline)
    }
}
