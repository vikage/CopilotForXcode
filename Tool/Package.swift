// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tool",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "Terminal", targets: ["Terminal"]),
        .library(name: "LangChain", targets: ["LangChain"]),
        .library(name: "PythonHelper", targets: ["PythonHelper"]),
        .library(name: "ExternalServices", targets: ["BingSearchService"]),
        .library(name: "Preferences", targets: ["Preferences", "Configs"]),
        .library(name: "Logger", targets: ["Logger"]),
        .library(name: "OpenAIService", targets: ["OpenAIService"]),
    ],
    dependencies: [
        .package(path: "../Python"),
        .package(url: "https://github.com/pvieito/PythonKit.git", branch: "master"),
        // TODO: Switch to Tiktoken. https://github.com/aespinilla/Tiktoken
        .package(url: "https://github.com/alfianlosari/GPTEncoder", from: "1.0.4"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.6.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    ],
    targets: [
        // MARK: - Helpers

        .target(name: "Configs"),

        .target(name: "Preferences", dependencies: ["Configs"]),

        .target(name: "Terminal"),

        .target(name: "Logger"),

        // MARK: - Services

        .target(
            name: "LangChain",
            dependencies: [
                "OpenAIService",
                "PythonHelper",
                .product(name: "PythonKit", package: "PythonKit"),
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ]
        ),

        .target(name: "BingSearchService"),

        .target(
            name: "PythonHelper",
            dependencies: [
                "Logger",
                .product(name: "Python", package: "Python"),
                .product(name: "PythonKit", package: "PythonKit"),
            ]
        ),

        // MARK: - OpenAI

        .target(
            name: "OpenAIService",
            dependencies: [
                "Logger",
                "Preferences",
                .product(name: "GPTEncoder", package: "GPTEncoder"),
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .testTarget(
            name: "OpenAIServiceTests",
            dependencies: ["OpenAIService"]
        ),

        // MARK: - Tests

        .testTarget(
            name: "LangChainTests",
            dependencies: ["LangChain"]
        ),
    ]
)

