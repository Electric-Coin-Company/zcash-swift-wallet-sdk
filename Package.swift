// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "ZcashLightClientKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ZcashLightClientKit",
            targets: ["ZcashLightClientKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.8.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1"),
        .package(url: "https://github.com/zcash-hackworks/zcash-light-client-ffi", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "ZcashLightClientKit",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "libzcashlc", package: "zcash-light-client-ffi")
            ],
            exclude: [
                "Service/ProtoBuf/proto/compact_formats.proto",
                "Service/ProtoBuf/proto/service.proto"
            ],
            resources: [
                .copy("Resources/checkpoints")
            ]
        ),
        .target(
            name: "TestUtils",
            dependencies: ["ZcashLightClientKit"],
            path: "Tests/TestUtils",
            exclude: [
                "proto/darkside.proto"
            ],
            resources: [
                .copy("Resources/test_data.db"),
                .copy("Resources/cache.db"),
                .copy("Resources/darkside_caches.db"),
                .copy("Resources/darkside_data.db"),
                .copy("Resources/darkside_pending.db"),
                .copy("Resources/sandblasted_mainnet_block.json")
            ]
        ),
        .testTarget(
            name: "OfflineTests",
            dependencies: ["ZcashLightClientKit", "TestUtils"]
        ),
        .testTarget(
            name: "NetworkTests",
            dependencies: ["ZcashLightClientKit", "TestUtils"]
        ),
        .testTarget(
            name: "DarksideTests",
            dependencies: ["ZcashLightClientKit", "TestUtils"]
        ),
        .testTarget(
            name: "PerformanceTests",
            dependencies: ["ZcashLightClientKit", "TestUtils"]
        )
    ]
)
