// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "screen-time-lib",
    platforms: [
        .macOS(.v13),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "screen-time-lib",
            targets: ["screentime"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.2.0")
    ],
    targets: [
        .target(
            name: "screentime",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Crypto", package: "swift-crypto")
            ]
        )
    ]
)
