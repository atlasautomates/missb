import Foundation

/// One column on the paper audit. Raw values are the payload's snake_case
/// keys, so autosave and the wire format share one spelling per check.
public enum Check: String, Codable, CaseIterable, Equatable, Sendable {
    case occ = "occ"
    case bedStatus = "bed_status"
    case iso = "iso"
    case cdiff = "cdiff"
    case braden = "braden"
    case schmid = "schmid"
    case bundleDoor = "bundle_door"
    case bundleRails = "bundle_rails"
    case bundleArm = "bundle_arm"
    case bundleSocks = "bundle_socks"
    case bundleBook = "bundle_book"
    case clabsiCL = "clabsi_cl"
    case clabsiDate = "clabsi_date"
    case clabsiABX = "clabsi_abx"
    case clabsiTPN = "clabsi_tpn"
    case cautiFC = "cauti_fc"
    case cautiDate = "cauti_date"
    case cautiPRC = "cauti_prc"
    case restraints = "restraints"
    case fr = "fr"
    case sitter = "sitter"
    case bariatric = "bariatric"

    /// CLABSI sub-checks are the only ones a nurse can mark N/A by hand.
    /// Empty-room and no-foley skips are applied by answer rules, not `skip()`.
    public var isManuallySkippable: Bool {
        switch self {
        case .clabsiCL, .clabsiDate, .clabsiABX, .clabsiTPN:
            true
        default:
            false
        }
    }

    /// DATE and PRC under CAUTI. F.C. = no skips these and nothing else.
    var isCautiTail: Bool {
        self == .cautiDate || self == .cautiPRC
    }
}

public enum CheckValue: Equatable, Codable, Sendable {
    case bool(Bool)
    case choice(String)
    case choices([String])
    case score(Int)
    case date(Date)
}

public enum SkipCause: String, Codable, Equatable, Sendable {
    case emptyRoom = "empty_room"
    case noFoley = "no_foley"
    case manual
}

public enum CheckState: Equatable, Codable, Sendable {
    case missing
    case answered(CheckValue)
    case skipped(SkipCause)
}
