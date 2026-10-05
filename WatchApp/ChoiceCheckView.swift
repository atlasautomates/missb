import SwiftUI

struct ChoiceCheckView: View {
    let options: [String]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    CheckTap(
                        selected: selected == option,
                        identifier: "option.\(option)",
                        action: { onSelect(option) }
                    ) {
                        Text(option.asCheckLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
        }
    }
}
