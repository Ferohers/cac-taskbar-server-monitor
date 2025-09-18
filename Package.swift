// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Duman",
    platforms: [
        .macOS(.v12)  // Apple Silicon optimization baseline
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
            cSettings: [
                // ARM64 specific optimizations
                .unsafeFlags([
                    "-mcpu=apple-m1",
                    "-O3", "-flto", 
                    "-ffast-math",
                    "-fomit-frame-pointer",
                    "-DARM64_OPTIMIZED=1",
                    "-DPOWER_EFFICIENT=1"
                ], .when(configuration: .release))
            ],
            swiftSettings: [
                .define("RELEASE", .when(configuration: .release)),
                .define("ARM64_OPTIMIZED"),
                .define("POWER_EFFICIENT"),
                // Apple Silicon specific optimizations
                .unsafeFlags([
                    "-O", "-whole-module-optimization",
                    "-cross-module-optimization",
                    "-enable-library-evolution"
                ], .when(configuration: .release))
            ]
        )
    ]
)
