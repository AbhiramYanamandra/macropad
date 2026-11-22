// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacropadStudio",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "MacropadStudio", targets: ["MacropadStudio"])],
    targets: [
        .target(name: "StudioCore", resources: [.process("Resources")]),
        .executableTarget(name: "MacropadStudio", dependencies: ["StudioCore"]),
        .testTarget(name: "StudioCoreTests", dependencies: ["StudioCore"]),
        .testTarget(name: "StudioUITests", dependencies: ["MacropadStudio", "StudioCore"])
    ]
)
