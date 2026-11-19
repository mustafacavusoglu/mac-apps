// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CopyHist",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "copy-hist", targets: ["CopyHist"]),
        .library(name: "CopyHistKit", targets: ["CopyHistKit"]),
    ],
    targets: [
        .target(name: "CopyHistKit", path: "Sources/CopyHistKit"),
        .executableTarget(name: "CopyHist", dependencies: ["CopyHistKit"], path: "Sources/CopyHist"),
    ]
)
