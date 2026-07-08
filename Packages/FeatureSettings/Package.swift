// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeatureSettings",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureSettings", targets: ["FeatureSettings"]),
    ],
    dependencies: [
        .package(path: "../PortoKit"),
        .package(path: "../PortoDesign"),
        .package(path: "../PortoForms"),
    ],
    targets: [
        .target(name: "FeatureSettings", dependencies: ["PortoKit", "PortoDesign", "PortoForms"]),
    ]
)
