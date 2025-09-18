// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Duman",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Duman",
            targets: ["Duman"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Duman",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("../icon/Duman.icns")
            ],
            swiftSettings: [
                .define("RELEASE", .when(configuration: .release))
            ]
        )
    ]
)
