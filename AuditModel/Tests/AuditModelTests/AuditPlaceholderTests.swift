import Testing
@testable import AuditModel

@Test func placeholderRoundTripsItsLabel() {
    let placeholder = AuditPlaceholder()
    #expect(placeholder == AuditPlaceholder(label: "placeholder"))
}
