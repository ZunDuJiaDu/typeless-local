// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Typeless",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TypelessKit", targets: ["Typeless"]),
        .executable(name: "Typeless", targets: ["TypelessApp"])
    ],
    targets: [
        .target(
            name: "Typeless",
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
            name: "TypelessApp",
            dependencies: ["Typeless"],
            path: "Sources/TypelessApp"
        ),
        .testTarget(
            name: "TypelessTests",
            dependencies: ["Typeless"],
            path: "Tests/TypelessAppTests"
        )
    ]
)
