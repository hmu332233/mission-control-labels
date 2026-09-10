// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MissionControlLabels",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "MissionControlLabelsCore",
            path: "Sources/MissionControlLabelsCore"
        ),
        .executableTarget(
            name: "MissionControlLabels",
            dependencies: ["MissionControlLabelsCore"],
            path: "Sources/MissionControlLabels",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .testTarget(
            name: "MissionControlLabelsCoreTests",
            dependencies: ["MissionControlLabelsCore"],
            path: "Tests/MissionControlLabelsCoreTests"
        ),
    ]
)
