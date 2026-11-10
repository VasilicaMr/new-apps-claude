// swift-tools-version:5.9
//
// PhysicsTrailCore — the inner rings of the app's clean architecture.
//   TrailDomain: entities, game rules, repository/service protocols, use cases. No UI, no I/O.
//   TrailData:   the physics content catalog + UserDefaults-backed repositories.
// The iOS app (Presentation + composition root) depends on both; Domain depends on nothing.
//

import PackageDescription

let package = Package(
    name: "PhysicsTrailCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TrailDomain", targets: ["TrailDomain"]),
        .library(name: "TrailData", targets: ["TrailData"]),
    ],
    targets: [
        .target(name: "TrailDomain"),
        .target(name: "TrailData", dependencies: ["TrailDomain"]),
        .testTarget(name: "TrailDomainTests", dependencies: ["TrailDomain"]),
        .testTarget(name: "TrailDataTests", dependencies: ["TrailData", "TrailDomain"]),
    ]
)
