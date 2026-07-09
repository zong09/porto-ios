// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PortoDesign",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PortoDesign", targets: ["PortoDesign"]),
    ],
    dependencies: [
        .package(path: "../PortoKit"),
    ],
    targets: [
        .target(name: "PortoDesign", dependencies: ["PortoKit"]),
        .testTarget(name: "PortoDesignTests", dependencies: ["PortoDesign"]),
    ]
)
