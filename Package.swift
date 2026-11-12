// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "A11ySweep",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "A11ySweep", targets: ["A11ySweep"])
    ],
    targets: [
        .target(name: "A11ySweepCore"),
        .target(name: "A11ySweep", dependencies: ["A11ySweepCore"]),
        .testTarget(name: "A11ySweepCoreTests", dependencies: ["A11ySweepCore"])
    ]
)
