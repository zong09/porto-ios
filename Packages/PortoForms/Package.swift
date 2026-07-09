// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PortoForms",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PortoForms", targets: ["PortoForms"]),
    ],
    dependencies: [
        .package(path: "../PortoKit"),
        .package(path: "../PortoDesign"),
    ],
    targets: [
        .target(name: "PortoForms", dependencies: ["PortoKit", "PortoDesign"]),
    ]
)
