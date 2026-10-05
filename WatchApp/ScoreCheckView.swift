import SwiftUI

/// Crown detent plus a tap list. The simulator crown does not move reliably,
/// same constraint the census control already works around.
struct ScoreCheckView: View {
    let range: ClosedRange<Int>
    let stored: Int?
    @Binding var picking: Bool
    let onCommit: (Int) -> Void

    @State private var value: Int
    @State private var touched: Bool
    @FocusState private var crownFocused: Bool

    init(range: ClosedRange<Int>, stored: Int?, picking: Binding<Bool>, onCommit: @escaping (Int) -> Void) {
        self.range = range
        self.stored = stored
        self.onCommit = onCommit
        _picking = picking
        _value = State(initialValue: stored ?? range.lowerBound)
        _touched = State(initialValue: stored != nil)
    }

    var body: some View {
        if picking {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(range), id: \.self) { number in
                        CheckTap(
                            selected: stored == number,
                            identifier: "score.\(number)",
                            action: { onCommit(number) }
                        ) {
                            Text("\(number)")
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 6) {
                Text(touched ? "\(value)" : "—")
                    .font(.largeTitle)
                    .focusable()
                    .focused($crownFocused)
                    .digitalCrownRotation(
                        detent: $value,
                        from: range.lowerBound,
                        through: range.upperBound,
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true,
                        onChange: { _ in touched = true }
                    )
                    .accessibilityIdentifier("score.value")
                Text("\(range.lowerBound)-\(range.upperBound)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    CheckTap(selected: false, identifier: "check.pick", action: { picking = true }) {
                        Text("Pick")
                    }
                    CheckTap(
                        selected: touched,
                        enabled: touched,
                        identifier: "check.set",
                        action: { onCommit(value) }
                    ) {
                        Text("Set")
                    }
                }
            }
            .onAppear { crownFocused = true }
        }
    }
}
