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
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.24.2"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3"),
//        .package(url: "https://github.com/Electric-Coin-Company/zcash-light-client-ffi", revision: "e88a70ae3691f49079f48a439c09e450c4bc5a7e")
//        .package(url: "https://github.com/Electric-Coin-Company/zcash-light-client-ffi", revision: "884e248c72a3c7e50b0cfac7251d3c48b8509393")
//            .package(url: "https://github.com/Electric-Coin-Company/zcash-light-client-ffi", branch: "fix/missing_gap_metadata")
        
        .package(url: "https://github.com/Electric-Coin-Company/zcash-light-client-ffi", revision: "981cfbe4a566487cc6a7cabd887e9ae011239559")
        
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
                "Modules/Service/GRPC/ProtoBuf/proto/compact_formats.proto",
                "Modules/Service/GRPC/ProtoBuf/proto/proposal.proto",
                "Modules/Service/GRPC/ProtoBuf/proto/service.proto",
                "Error/Sourcery/"
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
                "proto/darkside.proto",
                "Sourcery/AutoMockable.stencil",
                "Sourcery/generateMocks.sh"
            ],
            resources: [
                .copy("Resources/test_data.db"),
                .copy("Resources/cache.db"),
                .copy("Resources/darkside_caches.db"),
                .copy("Resources/darkside_data.db"),
                .copy("Resources/sandblasted_mainnet_block.json"),
                .copy("Resources/txBase64String.txt"),
                .copy("Resources/txFromAndroidSDK.txt"),
                .copy("Resources/integerOverflowJSON.json"),
                .copy("Resources/sapling-spend.params"),
                .copy("Resources/sapling-output.params")
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
            name: "AliasDarksideTests",
            dependencies: ["ZcashLightClientKit", "TestUtils"],
            exclude: [
                "scripts/"
            ]
        ),
        .testTarget(
            name: "PerformanceTests",
            dependencies: ["ZcashLightClientKit", "TestUtils"]
        )
    ]
)
