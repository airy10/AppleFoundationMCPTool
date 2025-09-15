import PackageDescription

let package = Package(
    name: "AppleFoundationMCPToolTests",
    dependencies: [
        .package(path: "../")
    ],
    targets: [
        .testTarget(
            name: "AppleFoundationMCPToolTests",
            dependencies: ["AppleFoundationMCPTool"])
    ]
)