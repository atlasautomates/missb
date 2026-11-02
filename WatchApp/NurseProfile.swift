import Foundation

struct NurseProfile: Identifiable, Equatable, Hashable {
    let name: String
    /// Glyph drawn in the profile circle and the room-list bar.
    let icon: String
    /// True for an identity typed through the "Other" tile — the one
    /// sanctioned typing path on the watch.
    let isCustom: Bool

    init(name: String, icon: String, isCustom: Bool = false) {
        self.name = name
        self.icon = icon
        self.isCustom = isCustom
    }

    var id: String { icon }

    /// What selecting this profile drops into ANM/RHC: presets contribute
    /// their initials glyph, a typed identity contributes the full name
    /// (ticket 014 — the typed name IS the ANM value).
    var anmValue: String { isCustom ? name : icon }

    /// Stable accessibility token. The Atlas glyph is an emoji, which is a poor identifier.
    var token: String {
        if isCustom { return "other" }
        switch icon {
        case "MB": return "MB"
        case "C": return "C"
        default: return "atlas"
        }
    }

    /// Identity typed via the "Other" tile. The circle glyph is derived
    /// initials (first letter of the first two words); the stored identity
    /// stays the full typed name.
    static func custom(name: String) -> NurseProfile {
        let initials = name.split(separator: " ").prefix(2).compactMap(\.first)
        let icon = initials.isEmpty ? "?" : String(initials).uppercased()
        return NurseProfile(name: name, icon: icon, isCustom: true)
    }

    static let all: [NurseProfile] = [
        NurseProfile(name: "Sheila Bernardez", icon: "MB"),
        NurseProfile(name: "Cecil", icon: "C"),
        NurseProfile(name: "Atlas", icon: "🦾"),
    ]
}
