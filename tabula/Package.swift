// swift-tools-version:5.9
import PackageDescription

// Shared/ ve Extension/ yolları post-build.sh için sabit; TabulaKit Shared/Files.swift'i yeniden kullanır.
let package = Package(
    name: "Tabula",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "tabula", targets: ["Tabula"]),
        .library(name: "TabulaKit", targets: ["TabulaKit"]),
    ],
    targets: [
        .target(name: "TabulaKit", path: ".", sources: ["Shared", "Sources/TabulaKit"]),
        .executableTarget(name: "Tabula", dependencies: ["TabulaKit"], path: ".", sources: ["Sources/Tabula"]),
    ]
)
