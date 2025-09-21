// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_mapbox_navigation",
    platforms: [
        .iOS("14.0"),
    ],
    products: [
        .library(name: "flutter-mapbox-navigation", targets: ["flutter_mapbox_navigation"])
    ],
    dependencies: [
        .package(url: "https://github.com/mapbox/mapbox-navigation-ios.git", from: "3.12.0")
    ],
    targets: [
        .target(
            name: "flutter_mapbox_navigation",
            dependencies: [
                .product(name: "MapboxNavigationCore", package: "mapbox-navigation-ios"),
                .product(name: "MapboxNavigationUIKit", package: "mapbox-navigation-ios")
            ],
            resources: []
        )
    ]
)
