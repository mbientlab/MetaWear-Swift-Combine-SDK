// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "MetaWear",
    platforms: [.macOS(.v10_15), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(name: "MetaWear", targets: ["MetaWear"]),
        .library(name: "MetaWearCpp", targets: ["MetaWearCpp"]),
        .library(name: "MetaWearSync", targets: ["MetaWearSync"]),
        .library(name: "MetaWearFirmware", targets: ["MetaWearFirmware"])
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
            exclude: [
                "./bindings",
                "./c-binding-generator",
                "./src/metawear/generator",
                "./config.mk",
                "./cppdocs",
                "./Doxyfile",
                "./LICENSE.md",
                "./Makefile",
                "./project_version.mk",
                "./README.md",
                "./test",
                "./MetaWear.Win32.vcxproj",
                "./MetaWear.WinRT.vcxproj"
            ],
            publicHeadersPath: "./src",
            cxxSettings: [
                .headerSearchPath("./src")
            ]
        ),
        .target(name: "MetaWearSync",
                dependencies: ["MetaWear"],
                path: "Sources/MetaWearSync"
               ),
        .target(
            name: "MetaWearFirmware",
            dependencies: ["NordicDFU", "MetaWear", "MetaWearCpp"],
            path: "Sources/MetaWearFirmware"
        ),
        .testTarget(name: "MetaWearTests", dependencies: ["MetaWear", "MetaWearCpp"])
    ],
    cxxLanguageStandard: .cxx11
)
