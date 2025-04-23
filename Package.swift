// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "MetaWear",
    platforms: [.macOS(.v11), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(name: "MetaWear", targets: ["MetaWear"]),
    ],
    dependencies: [
        .package(
            name: "NordicDFU",
            url: "https://github.com/NordicSemiconductor/IOS-DFU-Library",
            .exactItem(.init(4, 15, 3))
        )
    ],
    targets: [
        .target(
            name: "MetaWear",
            dependencies: ["NordicDFU"],
            path: "Sources/MetaWear"
        ),
        .testTarget(name: "MetaWearTests", dependencies: ["MetaWear"])
    ],
    cxxLanguageStandard: .cxx11
)
