// swift-tools-version:5.9
// The rules of AMS Seedboard: boards, the mind-map layout, arrows, text in and out,
// and what goes to PARAGON. No screen in it, so every rule can be tested in seconds.
import PackageDescription

let package = Package(
    name: "SeedboardCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SeedboardCore", targets: ["SeedboardCore"])],
    targets: [
        .target(name: "SeedboardCore"),
        .testTarget(name: "SeedboardCoreTests", dependencies: ["SeedboardCore"]),
    ]
)
