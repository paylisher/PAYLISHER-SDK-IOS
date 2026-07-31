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

        // OPTIONAL App Tracking Transparency / IDFA add-on.
        //
        // Link this ONLY if your app genuinely wants the advertising identifier. It is a
        // separate product on purpose: it is the sole owner of the `AdSupport` and
        // `AppTrackingTransparency` symbols, and App Review's ATT check is a binary symbol
        // scan, so an app that does not link it cannot be rejected for referencing ATT
        // (Guideline 2.5.1) and inherits no "Data Used to Track You" declaration.
        // A runtime flag could not achieve either, which is why this is not one.
        .library(
            name: "PaylisherATT",
            targets: ["PaylisherATT"]
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
            // MUST stay excluded. SwiftPM otherwise globs every file under `path`, which
            // would compile the ATT add-on straight into the core module and reintroduce the
            // AdSupport/AppTrackingTransparency symbols this split exists to remove.
            exclude: [
                "PaylisherATT"
            ],
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
        // Optional ATT/IDFA add-on. Ships its OWN privacy manifest declaring
        // NSPrivacyTracking=true; the core manifest declares false. Xcode aggregates only
        // the manifests actually present in the built app, so an app that never links this
        // target never picks up the tracking declaration.
        //
        // REQUIRES iOS 14+ in the CONSUMING app. SwiftPM has no per-target platform floor —
        // `platforms:` above is package-wide and stays at iOS 13 for the core library — so
        // this cannot be expressed declaratively. AppTrackingTransparency.framework does not
        // exist before iOS 14, and Swift autolinking emits a `-framework` load command from
        // the `import` regardless of the `#available` guards around the calls. An app that
        // still supports iOS 13 must therefore link the CocoaPods `Paylisher/ATT` subspec
        // (which pins 14.0 and weak-links the framework) or add `-weak_framework
        // AppTrackingTransparency` itself. Apps on iOS 14+ are unaffected.
        .target(
            name: "PaylisherATT",
            dependencies: ["Paylisher"],
            path: "Paylisher/PaylisherATT",
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy")
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


