// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "screen-time-lib",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "screen-time-lib",
            targets: ["screen-time-lib"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "screen-time-lib"),
        .testTarget(
            name: "screen-time-libTests",
            dependencies: ["screen-time-lib"]),
    ]
)
