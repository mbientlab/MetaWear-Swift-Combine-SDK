// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "MetaWear",
    platforms: [.macOS(.v11), .iOS(.v14), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(
            name: "MetaWear",
            targets: ["MetaWear"]),
    ],
    dependencies: [
        .package(
            name: "NordicDFU",
            url: "https://github.com/NordicSemiconductor/IOS-DFU-Library",
            .exactItem(.init(4, 11, 1))
        )
    ],
    targets: [
        .target(
            name: "MetaWear",
            dependencies: ["NordicDFU", "MetaWearCpp"],
            path: "Sources/MetaWear"
        ),
        .target(
            name: "MetaWearCpp",
            path: "Sources/MetaWearCpp",
            publicHeadersPath: "./src",
            cxxSettings: [
                .headerSearchPath("./src")
            ]
        ),
        .testTarget(name: "MetaWearTests",
                    dependencies: ["MetaWear", "MetaWearCpp"])
    ],
    cxxLanguageStandard: .cxx11
)
