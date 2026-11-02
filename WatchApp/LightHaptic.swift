import WatchKit

enum LightHaptic {
    /// Short click. Crown detents already haptic on their own.
    static func play() {
        WKInterfaceDevice.current().play(.click)
    }

    /// Room-complete beat for the warm look. Clinical stays on the light click.
    static func success() {
        WKInterfaceDevice.current().play(.success)
    }
}
