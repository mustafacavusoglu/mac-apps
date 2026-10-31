// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AltTab",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "alt-tab", targets: ["AltTab"])],
    targets: [.executableTarget(name: "AltTab", path: "Sources/AltTab")]
)
