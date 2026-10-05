import Foundation

struct NurseProfile: Identifiable, Equatable, Hashable {
    let name: String
    /// Glyph drawn in the circle and stored as ANM/RHC when this profile is picked there.
    let icon: String

    var id: String { icon }

    /// Stable accessibility token. The Atlas glyph is an emoji, which is a poor identifier.
    var token: String {
        switch icon {
        case "MB": "MB"
        case "C": "C"
        default: "atlas"
        }
    }

    static let all: [NurseProfile] = [
        NurseProfile(name: "Sheila Bernardez", icon: "MB"),
        NurseProfile(name: "Cecil", icon: "C"),
        NurseProfile(name: "Atlas", icon: "🦾"),
    ]
}
