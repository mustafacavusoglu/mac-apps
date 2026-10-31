// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacClear",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "mac-clear", targets: ["MacClear"])],
    targets: [.executableTarget(name: "MacClear", path: "Sources/MacClear")]
)
