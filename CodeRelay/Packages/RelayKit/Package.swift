// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "RelayKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RelayKit", targets: ["RelayKit"])
    ],
    targets: [
        .target(name: "RelayKit"),
        .testTarget(name: "RelayKitTests", dependencies: ["RelayKit"])
    ]
)
