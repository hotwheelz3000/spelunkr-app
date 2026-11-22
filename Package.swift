// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SPELUNKR",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "SPELUNKR",
            targets: ["SPELUNKR"]
        ),
    ],
    targets: [
        .target(
            name: "SPELUNKR",
            // The icon on the loading screen.
            resources: [.copy("LaunchIcon.png")]
        ),
    ]
)
