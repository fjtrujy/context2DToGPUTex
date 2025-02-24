// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Context2DToGPUTex",
    platforms: [.iOS(.v16), .macCatalyst(.v16), .macOS(.v14)],
    products: [
        .executable(name: "Context2DToGPUTex", targets: ["Context2DToGPUTex"]),
    ],
    targets: [
        .executableTarget(name: "Context2DToGPUTex"),
    ]
)
