public enum Side: String, Codable, Equatable, Sendable {
    case west
    case east

    public var rooms: [String] {
        switch self {
        case .west: Self.westRooms
        case .east: Self.eastRooms
        }
    }

    private static let westRooms: [String] = [
        "301", "302", "303", "304", "305", "306A", "306Z", "307", "308",
        "309", "310", "311", "312", "313", "314", "315", "316", "317",
        "318", "319", "320", "321", "322", "323", "324A", "324Z",
    ]

    private static let eastRooms: [String] = [
        "325A", "325Z", "326", "327", "328", "329", "330", "331", "332",
        "333", "334", "335", "336", "337", "338", "339", "340", "341",
        "342", "343A", "343Z", "344", "345", "346", "347", "348",
    ]
}
