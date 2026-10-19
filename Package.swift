// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CPStack",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "CPStack",
            path: "Sources/CPStack",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
