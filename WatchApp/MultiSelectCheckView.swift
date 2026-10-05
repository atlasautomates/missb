import SwiftUI

struct MultiSelectCheckView: View {
    let options: [String]
    let onCommit: ([String]) -> Void
    @State private var selected: Set<String>

    init(options: [String], stored: [String], onCommit: @escaping ([String]) -> Void) {
        self.options = options
        self.onCommit = onCommit
        _selected = State(initialValue: Set(stored))
    }

    var body: some View {
        VStack(spacing: 6) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        CheckTap(
                            selected: selected.contains(option),
                            identifier: "option.\(option)",
                            action: { toggle(option) }
                        ) {
                            HStack {
                                Text(option.asCheckLabel)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                Spacer(minLength: 4)
                                Image(systemName: selected.contains(option) ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            // The list must not paint over Done. Without a clip, the rows
            // draw outside the scroll view and sit on top of that button.
            .clipped()
            // An empty selection is a real answer (none). It is not "missing".
            CheckTap(selected: true, identifier: "check.done", action: commit) {
                Text(selected.isEmpty ? "Done — none" : "Done")
            }
        }
    }

    private func toggle(_ option: String) {
        if selected.contains(option) {
            selected.remove(option)
        } else {
            selected.insert(option)
        }
    }

    private func commit() {
        onCommit(options.filter { selected.contains($0) })
    }
}
