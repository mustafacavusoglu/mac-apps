// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SpeedTest",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "speed-test", targets: ["SpeedTest"]),
        .library(name: "SpeedTestKit", targets: ["SpeedTestKit"]),
    ],
    targets: [
        .target(name: "SpeedTestKit", path: "Sources/SpeedTestKit"),
        .executableTarget(name: "SpeedTest", dependencies: ["SpeedTestKit"], path: "Sources/SpeedTest"),
    ]
)
