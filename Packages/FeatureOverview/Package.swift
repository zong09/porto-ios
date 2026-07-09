// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeatureOverview",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureOverview", targets: ["FeatureOverview"]),
    ],
    dependencies: [
        .package(path: "../PortoKit"),
        .package(path: "../PortoDesign"),
        .package(path: "../PortoForms"),
    ],
    targets: [
        .target(name: "FeatureOverview", dependencies: ["PortoKit", "PortoDesign", "PortoForms"]),
    ]
)
