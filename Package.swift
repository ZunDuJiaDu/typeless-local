// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "WuZi",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "WuZiKit", targets: ["WuZi"]),
        .executable(name: "WuZi", targets: ["WuZiApp"])
    ],
    targets: [
        .target(
            name: "WuZi",
            path: "Sources",
            exclude: ["TypelessApp"],
            sources: [
                "App",
                "Audio",
                "Injection",
                "InputCapture",
                "LLM",
                "MenuBar",
                "Overlay",
                "Permissions",
                "Session",
                "Settings",
                "Speech",
                "Support"
            ]
        ),
        .executableTarget(
            name: "WuZiApp",
            dependencies: ["WuZi"],
            path: "Sources/TypelessApp"
        ),
        .testTarget(
            name: "WuZiTests",
            dependencies: ["WuZi"],
            path: "Tests/TypelessAppTests"
        )
    ]
)
