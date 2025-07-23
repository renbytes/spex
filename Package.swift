// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "Spex",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "spex", targets: ["Spex"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "4.1.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.1"),
        .package(url: "https://github.com/LebJe/TOMLKit", from: "0.6.0"),
        .package(url: "https://github.com/swiftpackages/DotEnv.git", from: "3.0.0"),
        .package(url: "https://github.com/dfreniche/SwiftFiglet", from: "0.2.1"),
        .package(url: "https://github.com/swiftcsv/SwiftCSV.git", from: "0.8.0"),
        
        // Dev UX Enhancements
        .package(url: "https://github.com/tuist/Noora.git", from: "0.43.0"),
        .package(url: "https://github.com/jkandzi/Progress.swift.git", from: "0.4.0"),
        .package(url: "https://github.com/JanGorman/Table.git", from: "1.1.1")
    ],
    targets: [
        .executableTarget(
            name: "Spex",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "TOMLKit", package: "TOMLKit"),
                .product(name: "DotEnv", package: "DotEnv"),
                .product(name: "SwiftFigletKit", package: "swiftfiglet"),
                .product(name: "SwiftCSV", package: "SwiftCSV"),
                // Noora transitively depends on Rainbow, so we don't need to declare it.
                .product(name: "Noora", package: "Noora"),
                .product(name: "Progress", package: "Progress.swift"),
                .product(name: "Table", package: "Table")
            ]
        ),
        .testTarget(
            name: "SpexTests",
            dependencies: ["Spex"]
        )
    ]
)