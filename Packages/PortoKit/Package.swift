// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PortoKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PortoKit", targets: ["PortoKit"]),
    ],
    targets: [
        .target(name: "PortoKit"),
        .testTarget(
            name: "PortoKitTests",
            dependencies: ["PortoKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
