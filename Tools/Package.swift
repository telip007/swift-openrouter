// swift-tools-version: 6.2

// Build-time tooling only. Kept in its own package so that consumers of
// OpenRouter never have to fetch or build the generator.

import PackageDescription

let package = Package(
    name: "OpenRouterTools",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.14.1"),
    ],
)
