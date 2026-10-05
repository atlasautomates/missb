import SwiftUI
import AuditModel

struct CheckFlowView: View {
    @Environment(FloorSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    let side: Side
    let room: String

    @State private var current: Check?
    @State private var picking = false

    var body: some View {
        let check = resolved
        CheckPage(
            title: CheckCursor.title(for: check),
            identifier: "check.\(check.rawValue)",
            onSkip: check.isManuallySkippable ? { skip(check) } : nil,
            onBack: { back(from: check) }
        ) {
            input(for: check)
                .id(check)
        }
        .onAppear {
            if current == nil {
                current = check
            }
        }
    }

    private var resolved: Check {
        if let current { return current }
        if let sheet = session.sheet(for: side) {
            return CheckCursor.entry(in: room, sheet: sheet)
        }
        return .bedStatus
    }

    @ViewBuilder
    private func input(for check: Check) -> some View {
        let state = session.sheet(for: side)?.state(of: check, in: room) ?? .missing
        switch check {
        case .occ:
            EmptyView()
        case .bedStatus:
            ChoiceCheckView(options: ["C", "D", "NB"], selected: choice(state), onSelect: commitChoice)
        case .iso:
            ChoiceCheckView(options: PlaceholderOptionLists.iso, selected: choice(state), onSelect: commitChoice)
        case .cdiff:
            ChoiceCheckView(options: ["+", "R-O"], selected: choice(state), onSelect: commitChoice)
        case .braden:
            ScoreCheckView(range: 6...23, stored: score(state), picking: $picking, onCommit: commitScore)
        case .schmid:
            ScoreCheckView(range: 0...6, stored: score(state), picking: $picking, onCommit: commitScore)
        case .bundleDoor:
            YesNoCheckView(emoji: "🚪", selected: flag(state), onAnswer: commitFlag)
        case .bundleRails:
            YesNoCheckView(emoji: "2️⃣", selected: flag(state), onAnswer: commitFlag)
        case .bundleArm:
            YesNoCheckView(emoji: "💪", selected: flag(state), onAnswer: commitFlag)
        case .bundleSocks:
            YesNoCheckView(emoji: "🧦", selected: flag(state), onAnswer: commitFlag)
        case .bundleBook:
            YesNoCheckView(emoji: "📕", selected: flag(state), onAnswer: commitFlag)
        case .clabsiCL:
            ChoiceCheckView(options: PlaceholderLineTypes.clabsiCL, selected: choice(state), onSelect: commitChoice)
        case .clabsiDate:
            DateCheckView(stored: date(state), picking: $picking, onCommit: commitDate)
        case .clabsiABX:
            YesNoCheckView(selected: flag(state), onAnswer: commitFlag)
        case .clabsiTPN:
            YesNoCheckView(selected: flag(state), onAnswer: commitFlag)
        case .cautiFC:
            YesNoCheckView(selected: flag(state), onAnswer: commitFlag)
        case .cautiDate:
            DateCheckView(stored: date(state), picking: $picking, onCommit: commitDate)
        case .cautiPRC:
            ChoiceCheckView(options: ["P", "R", "C"], selected: choice(state), onSelect: commitChoice)
        case .restraints:
            MultiSelectCheckView(
                options: PlaceholderOptionLists.restraints,
                stored: choices(state),
                onCommit: commitChoices
            )
        case .fr, .sitter, .bariatric:
            YesNoCheckView(selected: flag(state), onAnswer: commitFlag)
        }
    }

    private func commitChoice(_ value: String) {
        commit(.choice(value))
    }

    private func commitFlag(_ value: Bool) {
        commit(.bool(value))
    }

    private func commitScore(_ value: Int) {
        commit(.score(value))
    }

    private func commitDate(_ value: Date) {
        commit(.date(value))
    }

    private func commitChoices(_ value: [String]) {
        commit(.choices(value))
    }

    private func commit(_ value: CheckValue) {
        let check = resolved
        session.answer(side: side, room: room, check: check, value: value)
        advance(from: check)
    }

    private func skip(_ check: Check) {
        session.skip(side: side, room: room, check: check)
        advance(from: check)
    }

    private func advance(from check: Check) {
        picking = false
        guard let sheet = session.sheet(for: side) else {
            dismiss()
            return
        }
        if let next = CheckCursor.next(after: check, in: room, sheet: sheet) {
            current = next
        } else {
            // This room's last presented check. Pop to the list; do not open
            // the next room (list snap is a later ticket).
            dismiss()
        }
    }

    private func back(from check: Check) {
        if picking {
            picking = false
            return
        }
        guard let sheet = session.sheet(for: side),
              let previous = CheckCursor.previous(before: check, in: room, sheet: sheet) else {
            dismiss()
            return
        }
        picking = false
        current = previous
    }

    private func choice(_ state: CheckState) -> String? {
        if case .answered(.choice(let value)) = state { return value }
        return nil
    }

    private func flag(_ state: CheckState) -> Bool? {
        if case .answered(.bool(let value)) = state { return value }
        return nil
    }

    private func score(_ state: CheckState) -> Int? {
        if case .answered(.score(let value)) = state { return value }
        return nil
    }

    private func date(_ state: CheckState) -> Date? {
        if case .answered(.date(let value)) = state { return value }
        return nil
    }

    private func choices(_ state: CheckState) -> [String] {
        if case .answered(.choices(let value)) = state { return value }
        return []
    }
}
