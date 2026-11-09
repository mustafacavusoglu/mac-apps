// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CopyHist",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "copy-hist", targets: ["CopyHist"])],
    targets: [.executableTarget(name: "CopyHist", path: "Sources/CopyHist")]
)
