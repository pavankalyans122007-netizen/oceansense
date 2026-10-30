// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AeroBlue",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AeroBlue", targets: ["AeroBlue"]),
        .executable(name: "AeroBridge", targets: ["AeroBridge"])
    ],
    targets: [
        .executableTarget(name: "AeroBlue"),
        .executableTarget(name: "AeroBridge")
    ]
)
