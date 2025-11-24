// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppleFoundationMCPTool",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AppleFoundationMCPTool",
            targets: ["AppleFoundationMCPTool"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.1.0"),
        .package(
            url: "https://github.com/airy10/AnyLanguageModel.git",
            branch: "main",
            traits: ["MLX"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and on products in packages this package depends on.
        .target(
            name: "AppleFoundationMCPTool",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "AnyLanguageModel", package: "AnyLanguageModel") // Disable to support only Apple models
            ]),
        .testTarget(
            name: "AppleFoundationMCPToolTests",
            dependencies: [
                "AppleFoundationMCPTool"
            ]),
        .executableTarget(
            name: "AppleFoundationMCPToolExample",
            dependencies: [
                "AppleFoundationMCPTool",
            ]),
        .executableTarget(
            name: "AppleFoundationMCPToolChat",
            dependencies: [
                "AppleFoundationMCPTool",
            ]
        )
    ]
)
