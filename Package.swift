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
            ],
            // SSL public key pinning is compiled in by default. To produce a build with pinning
            // fully excluded (for example the pentest package), remove this define. The decision
            // is taken at COMPILE time and cannot be reversed at runtime.
            swiftSettings: [
                .define("PAYLISHER_SSL_PINNING")
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
            url: "https://github.com/paylisher/PAYLISHER-SDK-IOS/releases/download/1.9.0/PaylisherFramework.xcframework.zip",
            checksum: "286d8d899e11d2528832c235a446ee6012f733df303cc7019161a50275758feb"
        ),
        // Self-contained NSE helper — Foundation + UserNotifications only.
        .target(
            name: "PaylisherNotificationServiceExtension",
            path: "PaylisherNotificationServiceExtension/Sources"
        )
    ]
)


