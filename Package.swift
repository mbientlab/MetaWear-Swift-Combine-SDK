// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "MetaWear",
    platforms: [.macOS(.v10_15), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(name: "MetaWear", targets: ["MetaWear"]),
        .library(name: "MetaWearCpp", targets: ["MetaWearCpp"]),
        .library(name: "MetaWearSync", targets: ["MetaWearSync"])
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
                "./src/generator",
                "./config.mk",
                "./cppdocs",
                "./Doxyfile",
                "./LICSENSE.md",
                "./Makefile",
                "./metawear_src.tar",
                "./project_version.mk",
                "./README.md",
                "./test",
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
        .testTarget(name: "MetaWearTests", dependencies: ["MetaWear", "MetaWearCpp"])
    ],
    cxxLanguageStandard: .cxx11
)
