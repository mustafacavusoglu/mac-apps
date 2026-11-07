// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tabula",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "tabula", targets: ["Tabula"])],
    targets: [.executableTarget(name: "Tabula", path: ".", sources: ["Sources/Tabula", "Shared"])]
)
