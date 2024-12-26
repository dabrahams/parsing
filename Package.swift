// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "parsing",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "parsing",
            targets: ["parsing"]),
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
      .package(url: "https://github.com/apple/swift-collections", from: "1.1.4"),
      .package(url: "https://github.com/tevelee/swift-graphs.git", from: "0.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
          name: "parsing",
          dependencies: [
            .product(name: "Algorithms", package: "swift-algorithms"),
            .product(name: "Collections", package: "swift-collections"),
            .product(name: "Graphs", package: "swift-graphs"),
          ]
        ),
        .testTarget(
            name: "parsingTests",
            dependencies: ["parsing"]
        ),
    ]
)
