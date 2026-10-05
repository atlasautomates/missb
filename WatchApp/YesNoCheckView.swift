import SwiftUI

struct YesNoCheckView: View {
    var emoji: String?
    var selected: Bool?
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(spacing: 6) {
            if let emoji {
                Text(emoji)
                    .font(.largeTitle)
            }
            answer("Yes", value: true, tint: .green, identifier: "option.yes")
            answer("No", value: false, tint: .red, identifier: "option.no")
        }
    }

    private func answer(_ title: String, value: Bool, tint: Color, identifier: String) -> some View {
        let filled = selected == nil || selected == value
        return CheckTap(
            selected: filled,
            tint: tint,
            identifier: identifier,
            action: { onAnswer(value) }
        ) {
            Text(title)
        }
    }
}
