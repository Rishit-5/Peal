// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PealShared",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "PealShared", targets: ["PealShared"])
    ],
    targets: [
        .target(name: "PealShared")
    ]
)
