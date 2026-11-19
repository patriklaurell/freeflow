// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FreeFlowLocal",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FreeFlowLocal", targets: ["FreeFlowLocal"]),
        .executable(name: "ParakeetSmoke", targets: ["ParakeetSmoke"]),
        .executable(name: "CleanupSmoke", targets: ["CleanupSmoke"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", revision: "4c21c84ba239583d6448dc38bbc9001e2df714a6", traits: []),
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.33.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", revision: "bd29696aa427a913812c7ef5cb03874633b04bfa"),
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            revision: "16780f04d2ece24f67d0fc00efccd0296491c1a8",
            traits: []
        ),
    ],
    targets: [
        .target(name: "LocalCleanup", dependencies: [
            .product(name: "MLX", package: "mlx-swift"),
            .product(name: "MLXLLM", package: "mlx-swift-lm"),
            .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            .product(name: "Tokenizers", package: "swift-transformers"),
        ], path: "LocalCleanup"),
        .executableTarget(name: "CleanupSmoke", dependencies: ["LocalCleanup"], path: "CleanupSmoke"),
        .target(
            name: "LocalASR",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            path: "LocalASR"
        ),
        .executableTarget(
            name: "FreeFlowLocal",
            dependencies: ["LocalASR", "LocalCleanup"],
            path: "Sources",
            swiftSettings: [.define("FREEFLOW_LOCAL")]
        ),
        .executableTarget(
            name: "ParakeetSmoke",
            dependencies: ["LocalASR"],
            path: "SmokeTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
