// swift-tools-version:5.9
import PackageDescription

// macOne: dört uygulamanın (Alt-Tab, Copy-Hist, Tabula, Mac-Clear) ve Stats'ın tek uygulamada birleşimi.
// Her özellik kendi paketinin kütüphane ürününden gelir; standalone uygulamalar da aynı kodu kullanır.
let package = Package(
    name: "macOne",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "macOne", targets: ["macOne"])],
    dependencies: [
        .package(path: "../alt-tab"),
        .package(path: "../copy-hist"),
        .package(path: "../tabula"),
        .package(path: "../mac-clear"),
    ],
    targets: [
        .executableTarget(
            name: "macOne",
            dependencies: [
                .product(name: "AltTabKit", package: "alt-tab"),
                .product(name: "CopyHistKit", package: "copy-hist"),
                .product(name: "TabulaKit", package: "tabula"),
                .product(name: "MacClearKit", package: "mac-clear"),
            ],
            path: "Sources/macOne"
        ),
    ]
)
