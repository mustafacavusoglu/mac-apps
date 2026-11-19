// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AltTab",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "alt-tab", targets: ["AltTab"]),
        .library(name: "AltTabKit", targets: ["AltTabKit"]),
    ],
    targets: [
        .target(name: "AltTabKit", path: "Sources/AltTabKit"),
        .executableTarget(name: "AltTab", dependencies: ["AltTabKit"], path: "Sources/AltTab"),
    ]
)
