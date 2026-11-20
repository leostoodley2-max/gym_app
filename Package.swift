// swift-tools-version:5.9
// Builds the platform-independent core of LiftBros (models, scoring, leaderboards, mock backend)
// so it can be unit-tested with `swift test` on macOS or Linux, without Xcode or a simulator.
// The iOS app itself is built from LiftBros.xcodeproj.
import PackageDescription

let package = Package(
    name: "LiftBrosCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LiftBrosCore", targets: ["LiftBrosCore"]),
    ],
    targets: [
        .target(name: "LiftBrosCore", path: "LiftBros/Core"),
        .testTarget(name: "LiftBrosCoreTests", dependencies: ["LiftBrosCore"], path: "Tests/LiftBrosCoreTests"),
    ]
)
