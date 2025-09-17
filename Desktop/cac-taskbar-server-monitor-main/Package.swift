// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AltanMon",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AltanMon",
            targets: ["AltanMon"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AltanMon",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ],
            path: "Sources",
            resources: [
                .copy("../icon/AltanMon.icns")
            ]
        )
    ]
)
