// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AuditModel",
    products: [
        .library(name: "AuditModel", targets: ["AuditModel"]),
    ],
    targets: [
        .target(name: "AuditModel"),
        .testTarget(
            name: "AuditModelTests",
            dependencies: ["AuditModel"]
        ),
    ]
)
