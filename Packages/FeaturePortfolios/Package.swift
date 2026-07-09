// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeaturePortfolios",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeaturePortfolios", targets: ["FeaturePortfolios"]),
    ],
    dependencies: [
        .package(path: "../PortoKit"),
        .package(path: "../PortoDesign"),
        .package(path: "../PortoForms"),
    ],
    targets: [
        .target(name: "FeaturePortfolios", dependencies: ["PortoKit", "PortoDesign", "PortoForms"]),
    ]
)
