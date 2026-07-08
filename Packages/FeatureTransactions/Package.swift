// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeatureTransactions",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureTransactions", targets: ["FeatureTransactions"]),
    ],
    dependencies: [
        .package(path: "../PortoKit"),
        .package(path: "../PortoDesign"),
        .package(path: "../PortoForms"),
    ],
    targets: [
        .target(name: "FeatureTransactions", dependencies: ["PortoKit", "PortoDesign", "PortoForms"]),
    ]
)
