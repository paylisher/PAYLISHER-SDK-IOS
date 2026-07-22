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
        ),

        // Lightweight, extension-safe helper for a Notification Service Extension
        // (per-device push language). Depends on nothing from the main Paylisher
        // target (no UIKit / Replay), so it is safe to link into an NSE. Add it
        // to your NSE target ONLY.
        .library(
            name: "PaylisherNotificationServiceExtension",
            targets: ["PaylisherNotificationServiceExtension"]
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
            url: "https://github.com/paylisher/PAYLISHER-SDK-IOS/releases/download/1.8.8/PaylisherFramework.xcframework.zip",
            checksum: "8289ef658950989d3c579401affd00ec2d8b842f26a89484b559a110ac3c54b0"
        ),
        // Self-contained NSE helper — Foundation + UserNotifications only.
        .target(
            name: "PaylisherNotificationServiceExtension",
            path: "PaylisherNotificationServiceExtension/Sources"
        )
    ]
)


