// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Paylisher",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6),
    ],
    products: [
        
        .library(
            name: "Paylisher",
            targets: ["Paylisher"]
        ),
        
        .library(
            name: "PaylisherFramework",
            targets: ["PaylisherFramework"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", from: "6.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "12.0.0"),
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", from: "9.0.0"),
    ],
    targets: [
        .target(
            name: "Paylisher",
            path: "Paylisher",
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy"),
                .process("Resources/PaylisherDatabase.momd")
            ]
        ),
        .testTarget(
            name: "PaylisherTests",
            dependencies: [
                "Paylisher",
                "Quick",
                "Nimble",
                "OHHTTPStubs",
                .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs"),
            ],
            path: "PaylisherTests"
        ),
        .binaryTarget(
            name: "PaylisherFramework",
            url: "https://github.com/paylisher/PAYLISHER-SDK-IOS/releases/download/1.8.5/PaylisherFramework.xcframework.zip",
            checksum: "f1527cab8ff57eea841b96245eb905c4ba2a4d657e5098ebec166fc76d21ab5a"
        )
    ]
)


