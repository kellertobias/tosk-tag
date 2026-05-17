// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TagEditor",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/chicio/ID3TagEditor.git", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TagEditor",
            dependencies: ["ID3TagEditor"]
        ),
        .testTarget(
            name: "TagEditorTests",
            dependencies: ["TagEditor"]
        ),
    ]
)
