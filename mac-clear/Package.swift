// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacClear",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "mac-clear", targets: ["MacClear"]),
        .library(name: "MacClearKit", targets: ["MacClearKit"]),
    ],
    targets: [
        .target(name: "MacClearKit", path: "Sources/MacClearKit"),
        .executableTarget(name: "MacClear", dependencies: ["MacClearKit"], path: "Sources/MacClear"),
    ]
)
