// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Eureka",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "Eureka", targets: ["Eureka"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-cmark.git", exact: "0.8.0")
    ],
    targets: [
        .executableTarget(
            name: "Eureka",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark")
            ],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("WebKit")
            ]
        )
    ]
)
