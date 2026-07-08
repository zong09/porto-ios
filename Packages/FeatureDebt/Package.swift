// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeatureDebt",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureDebt", targets: ["FeatureDebt"]),
    ],
    dependencies: [
        .package(path: "../PortoKit"),
        .package(path: "../PortoDesign"),
        .package(path: "../PortoForms"),
    ],
    targets: [
        .target(name: "FeatureDebt", dependencies: ["PortoKit", "PortoDesign", "PortoForms"]),
    ]
)
