// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VideoWorkspace",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VideoWorkspace", targets: ["VideoWorkspace"])
    ],
    targets: [
        .executableTarget(
            name: "VideoWorkspace",
            path: "Sources/VideoWorkspace",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "VideoWorkspaceTests",
            dependencies: ["VideoWorkspace"],
            path: "Tests/VideoWorkspaceTests"
        )
    ]
)
