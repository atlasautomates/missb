import AuditModel

extension Side: Hashable {
    /// NavigationPath needs Hashable. The domain enum only declares Equatable;
    /// the raw value is the identity.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }

    var title: String {
        switch self {
        case .west: "West"
        case .east: "East"
        }
    }
}
