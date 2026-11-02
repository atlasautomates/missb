import SwiftUI

struct YesNoCheckView: View {
    @Environment(LookTryOn.self) private var looks
    var emoji: String?
    var selected: Bool?
    let onAnswer: (Bool) -> Void

    var body: some View {
        switch looks.current {
        case .clinical:
            clinical
        case .warm:
            warm
        }
    }

    /// One accent. Yes is the step. No is a quiet row under it.
    private var clinical: some View {
        VStack(spacing: 8) {
            if let emoji {
                Text(emoji)
                    .font(.title2)
            }
            CheckTap(selected: true, tint: LookPalette.teal, identifier: "option.yes", action: { onAnswer(true) }) {
                HStack {
                    Text("Yes")
                    if selected == true {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                    }
                }
            }
            CheckTap(selected: false, identifier: "option.no", action: { onAnswer(false) }) {
                HStack {
                    Text("No")
                    if selected == false {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                    }
                }
            }
        }
    }

    /// Equal pair. The answer is a choice between two faces, not a primary and a leftover.
    private var warm: some View {
        VStack(spacing: 8) {
            if let emoji {
                Text(emoji)
                    .font(.largeTitle)
            }
            HStack(spacing: 8) {
                bubble("Yes", value: true, tint: LookPalette.leaf, identifier: "option.yes")
                bubble("No", value: false, tint: LookPalette.coral, identifier: "option.no")
            }
        }
    }

    private func bubble(_ title: String, value: Bool, tint: Color, identifier: String) -> some View {
        CheckTap(selected: true, tint: tint, identifier: identifier, action: { onAnswer(value) }) {
            VStack(spacing: 2) {
                Text(title)
                if selected == value {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
    }
}
