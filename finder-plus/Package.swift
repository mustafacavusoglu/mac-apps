// swift-tools-version:5.9
import PackageDescription

// Shared/ ve Extension/ yolları post-build.sh için sabit; FinderPlusKit Shared/Files.swift'i yeniden kullanır.
let package = Package(
    name: "FinderPlus",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "finder-plus", targets: ["FinderPlus"]),
        .library(name: "FinderPlusKit", targets: ["FinderPlusKit"]),
    ],
    targets: [
        .target(name: "FinderPlusKit", path: ".", sources: ["Shared", "Sources/FinderPlusKit"]),
        .executableTarget(name: "FinderPlus", dependencies: ["FinderPlusKit"], path: ".", sources: ["Sources/FinderPlus"]),
    ]
)
