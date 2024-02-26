// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "screen-time-lib",
    products: [
        .library(
            name: "screen-time-lib",
            targets: ["screen-time-lib"]
        ),
    ],
    targets: [
        .target(
            name: "screen-time-lib"
        )
    ]
)
