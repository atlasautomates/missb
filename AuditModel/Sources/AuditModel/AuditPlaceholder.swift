// Domain library for the audit. Must not import SwiftUI, WatchKit, UIKit, or any network stack —
// the watch UI and the courier stay outside this module. This type is a scaffold stand-in.
public struct AuditPlaceholder: Equatable, Sendable {
    public var label: String

    public init(label: String = "placeholder") {
        self.label = label
    }
}
