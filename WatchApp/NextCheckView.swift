import SwiftUI

struct NextCheckView: View {
    let room: String

    var body: some View {
        VStack(spacing: 8) {
            Text("Next check")
                .font(.headline)
            Text("Room \(room)")
            Text("The rest of this room's checks come later.")
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .navigationTitle(room)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("next.check")
    }
}
