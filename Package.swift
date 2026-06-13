// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Sorted",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Sorted", targets: ["Sorted"])
    ],
    targets: [
        .target(name: "SortedCore"),
        .executableTarget(
            name: "Sorted",
            dependencies: ["SortedCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .executableTarget(name: "SortedChecks", dependencies: ["SortedCore"])
    ]
)
