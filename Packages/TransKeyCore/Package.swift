// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TransKeyCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TransKeyCore", targets: ["TransKeyCore"])
    ],
    targets: [
        .target(name: "TransKeyCore"),
        .testTarget(name: "TransKeyCoreTests", dependencies: ["TransKeyCore"])
    ]
)
