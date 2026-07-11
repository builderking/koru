// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Koru",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KoruDomain", targets: ["KoruDomain"]),
        .library(name: "KoruPlatform", targets: ["KoruPlatform"]),
        .library(name: "KoruUI", targets: ["KoruUI"]),
        .executable(name: "Koru", targets: ["KoruApp"]),
        .executable(name: "KoruIntegrationHarness", targets: ["KoruIntegrationHarness"]),
    ],
    targets: [
        .target(name: "KoruDomain", path: "Packages/KoruCore/Sources/KoruDomain"),
        .target(name: "KoruPlatform", dependencies: ["KoruDomain"], path: "Packages/KoruPlatform/Sources/KoruPlatform"),
        .target(name: "KoruUI", dependencies: ["KoruDomain"], path: "Packages/KoruUI/Sources/KoruUI"),
        .executableTarget(name: "KoruApp", dependencies: ["KoruDomain", "KoruPlatform", "KoruUI"], path: "App"),
        .executableTarget(name: "KoruIntegrationHarness", dependencies: ["KoruDomain", "KoruPlatform", "KoruUI"], path: "Harness"),
        .testTarget(name: "KoruDomainTests", dependencies: ["KoruDomain"], path: "Tests/KoruDomainTests"),
        .testTarget(name: "KoruPlatformTests", dependencies: ["KoruPlatform", "KoruDomain"], path: "Tests/KoruPlatformTests"),
    ]
)
