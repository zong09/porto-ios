// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeatureAuth",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureAuth", targets: ["FeatureAuth"]),
    ],
    dependencies: [
        .package(path: "../PortoKit"),
        .package(path: "../PortoDesign"),
        .package(path: "../PortoForms"),
    ],
    targets: [
        .target(name: "FeatureAuth", dependencies: ["PortoKit", "PortoDesign", "PortoForms"]),
    ]
)
