// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "MetaWear",
    platforms: [.macOS(.v10_14), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)],
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
            dependencies: [.byName(name: "NordicDFU")]
        ),
        .target(
            name: "MetaWearCpp"
//            exclude: <#T##[String]#>,
//            cxxSettings: <#T##[CXXSetting]?#>,
//            linkerSettings: <#T##[LinkerSetting]?#>
        ),
        .testTarget(
            name: "MetaWearTests",
            dependencies: ["MetaWear"]),
    ]
)
