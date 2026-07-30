//
//  PaylisherATT.swift
//  PaylisherATT
//
//  Created by Paylisher SDK
//

#if os(iOS)

    import Foundation
    import UIKit

    // Under SwiftPM this is a separate module and must import the core one. Under CocoaPods
    // every subspec compiles into the single `Paylisher` module, where the import would be a
    // self-import (Swift warns and ignores it), so it is conditional on SPM.
    #if SWIFT_PACKAGE
        import Paylisher
    #endif

    #if canImport(AdSupport)
        import AdSupport
    #endif
    #if canImport(AppTrackingTransparency)
        import AppTrackingTransparency
    #endif

    /// App Tracking Transparency authorization state, mirrored so callers never have to
    /// import `AppTrackingTransparency` themselves.
    @objc(PaylisherATTStatus)
    public enum PaylisherATTStatus: Int {
        /// The user has not been asked yet.
        case notDetermined = 0
        /// Authorization is restricted by device policy (MDM, Screen Time) and cannot change.
        case restricted = 1
        /// The user declined.
        case denied = 2
        /// The user granted permission — and only in this state does an IDFA exist.
        case authorized = 3
        /// ATT is unavailable on this OS version (below iOS 14).
        case unavailable = 4

        /// Stable lowercase name used for the `PaylisherIDFAProviding` bridge and for
        /// reporting. Kept in sync with the Android SDK's consent vocabulary.
        public var name: String {
            switch self {
            case .notDetermined: return "notDetermined"
            case .restricted: return "restricted"
            case .denied: return "denied"
            case .authorized: return "authorized"
            case .unavailable: return "unavailable"
            }
        }
    }

    /**
     * OPTIONAL App Tracking Transparency / IDFA add-on for the Paylisher SDK.
     *
     * ─────────────────────────────────────────────────────────────────────────────────────
     * WHY THIS IS A SEPARATE MODULE
     * ─────────────────────────────────────────────────────────────────────────────────────
     * This file is the ONLY place in the entire SDK that imports `AdSupport` or
     * `AppTrackingTransparency`. The core `Paylisher` module contains none of those symbols.
     *
     * That separation is not cosmetic. App Review's ATT check is a binary symbol scan, and
     * it rejects in both directions:
     *
     *   - Guideline 2.5.1 — "your app's binary contains references to App Tracking
     *     Transparency, but you have indicated you do not intend to ask users for permission
     *     to track… you may also choose to fully remove other references to the
     *     AppTrackingTransparency framework."
     *   - Guideline 2.1 — "The app uses the AppTrackingTransparency framework, but we are
     *     unable to locate the App Tracking Transparency permission request."
     *
     * A runtime `enabled = false` switch cannot delete a symbol, so it cannot answer either
     * rejection. Only absence can. An app that does not link this module therefore inherits
     * no ATT symbols, no tracking declaration in its privacy report, and no obligation to
     * present a prompt. The same architecture Firebase uses (`GoogleAppMeasurement` vs its
     * tiny `IdentitySupport` shim) and AppsFlyer uses (the `Strict` / `AFSDK_NO_IDFA` build
     * with its own downgraded manifest).
     *
     * ─────────────────────────────────────────────────────────────────────────────────────
     * THE SDK NEVER PROMPTS ON ITS OWN
     * ─────────────────────────────────────────────────────────────────────────────────────
     * `enable()` only registers a reader. It does not prompt, and nothing inside the SDK
     * ever calls `requestAuthorization`. The permission dialog appears exactly once, when
     * YOUR code calls `PaylisherATT.requestAuthorization(...)` at a moment you choose. Every
     * internal read goes through `authorizedIDFA()`, which inspects the already-settled
     * status and returns `nil` unless it is `.authorized`.
     *
     * ─────────────────────────────────────────────────────────────────────────────────────
     * INTEGRATION
     * ─────────────────────────────────────────────────────────────────────────────────────
     * 1. Link this module (SPM product `PaylisherATT`, or CocoaPods `pod 'Paylisher/ATT'`).
     * 2. Add `NSUserTrackingUsageDescription` to your Info.plist. Without it iOS terminates
     *    the process on `requestTrackingAuthorization`; this class refuses to call it and
     *    logs instead, but you still get no prompt.
     * 3. Opt in at startup and turn the runtime flag on:
     *
     *        PaylisherATT.enable()
     *        let ddl = PaylisherDeferredDeepLinkConfig()
     *        ddl.includeIDFA = true
     *        config.deferredDeepLinkConfig = ddl
     *        PaylisherSDK.shared.setup(config)
     *
     * 4. Ask for permission when it makes sense in your onboarding — not on cold start:
     *
     *        PaylisherATT.requestAuthorization { status in
     *            print("ATT settled: \(status.name)")
     *        }
     *
     * To switch the capability off at runtime without shipping a new build path, call
     * `PaylisherATT.disable()` or set `includeIDFA = false`. To remove it from the binary
     * entirely, stop linking this module.
     */
    @objc(PaylisherATT)
    public final class PaylisherATT: NSObject, PaylisherIDFAProviding {
        /// Info.plist key iOS requires before the ATT prompt may be shown.
        private static let usageDescriptionKey = "NSUserTrackingUsageDescription"

        /// The all-zero IDFA iOS hands back when tracking is not permitted.
        private static let zeroIDFA = "00000000-0000-0000-0000-000000000000"

        private static let stateLock = NSLock()
        private static var _isEnabled = false

        /// Set to true to log what this module decides and why. Off by default so the module
        /// is silent in production builds.
        @objc public static var debugLogging = false

        override private init() {
            super.init()
        }

        // MARK: - Opt in / out

        /// Registers this module as the SDK's advertising-identifier provider.
        ///
        /// Call once, before `PaylisherSDK.shared.setup(_:)`. Idempotent. This does NOT show
        /// the ATT prompt and does NOT read the IDFA — it only makes the read possible for a
        /// user who has already authorized tracking.
        @objc public static func enable() {
            stateLock.lock()
            let alreadyEnabled = _isEnabled
            _isEnabled = true
            stateLock.unlock()

            guard !alreadyEnabled else {
                log("enable() ignored — already enabled")
                return
            }

            PaylisherIDFA.register(PaylisherATT.self)
            log("enabled — IDFA layer registered (no prompt shown, no identifier read yet)")

            if !hasUsageDescription() {
                log(
                    "WARNING: \(usageDescriptionKey) is missing from Info.plist. "
                        + "requestAuthorization(_:) will refuse to run, so the status can never "
                        + "become .authorized and no IDFA will ever be available."
                )
            }
        }

        /// Runtime kill switch: unregisters the provider so the SDK can no longer read an
        /// advertising identifier. Does not revoke the user's ATT decision — only iOS
        /// Settings can do that.
        @objc public static func disable() {
            stateLock.lock()
            _isEnabled = false
            stateLock.unlock()

            PaylisherIDFA.unregister()
            log("disabled — IDFA layer unregistered")
        }

        /// Whether `enable()` is currently in effect.
        @objc public static var isEnabled: Bool {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _isEnabled
        }

        // MARK: - Host-triggered authorization

        /// Current ATT authorization status. Reading this never prompts.
        @objc public static var status: PaylisherATTStatus {
            #if canImport(AppTrackingTransparency)
                if #available(iOS 14, *) {
                    switch ATTrackingManager.trackingAuthorizationStatus {
                    case .notDetermined: return .notDetermined
                    case .restricted: return .restricted
                    case .denied: return .denied
                    case .authorized: return .authorized
                    @unknown default: return .unavailable
                    }
                }
            #endif
            // Below iOS 14 there is no ATT. We deliberately do NOT fall back to the
            // deprecated `isAdvertisingTrackingEnabled`: without an explicit, recorded user
            // decision we treat the identifier as unavailable rather than assume consent.
            return .unavailable
        }

        /**
         * Presents the system App Tracking Transparency prompt — the ONLY place in the SDK
         * that can do so, and only because you called it.
         *
         * Behaviour worth knowing:
         * - If `NSUserTrackingUsageDescription` is missing from your Info.plist this method
         *   refuses to call into ATT and reports `.unavailable`. iOS would otherwise
         *   terminate the process, and a crash at review time is an automatic rejection.
         * - The prompt only appears when the status is `.notDetermined`. Once the user has
         *   answered, iOS shows nothing and this returns the settled value immediately.
         * - iOS only presents the dialog while the app is active. Calling it from
         *   `didFinishLaunching`, mid-transition or from the background commonly results in
         *   a silent `.denied`; a warning is logged when that is detected.
         * - `completion` is always invoked, always on the main thread.
         *
         * - Parameter completion: receives the settled authorization status.
         */
        @objc public static func requestAuthorization(completion: ((PaylisherATTStatus) -> Void)? = nil) {
            func finish(_ result: PaylisherATTStatus) {
                if Thread.isMainThread {
                    completion?(result)
                } else {
                    DispatchQueue.main.async { completion?(result) }
                }
            }

            guard hasUsageDescription() else {
                log(
                    "requestAuthorization refused — \(usageDescriptionKey) is missing from "
                        + "Info.plist. Add it, otherwise iOS terminates the app on this call."
                )
                finish(.unavailable)
                return
            }

            #if canImport(AppTrackingTransparency)
                if #available(iOS 14, *) {
                    DispatchQueue.main.async {
                        if UIApplication.shared.applicationState != .active {
                            log(
                                "WARNING: requesting ATT while the app is not active. iOS may "
                                    + "skip the dialog and settle on .denied. Prefer calling this "
                                    + "from an onboarding screen that is already on-screen."
                            )
                        }
                        ATTrackingManager.requestTrackingAuthorization { _ in
                            let settled = status
                            log("ATT settled: \(settled.name)")
                            finish(settled)
                        }
                    }
                    return
                }
            #endif

            log("ATT unavailable on this OS version")
            finish(.unavailable)
        }

        // MARK: - Identifier

        /// The advertising identifier, or `nil` when it is not available.
        ///
        /// Returns a value only when ATT is ALREADY `.authorized`. Never prompts.
        @objc public static var advertisingIdentifier: String? {
            authorizedIDFA()
        }

        // MARK: - PaylisherIDFAProviding

        /// Reads the IDFA only when authorization has already been granted. Never prompts.
        ///
        /// Called by the core SDK through `PaylisherIDFA`. Returns `nil` when tracking is not
        /// authorized, when this module has been disabled, or when iOS hands back the
        /// all-zero identifier (which it does for restricted or opted-out devices even in
        /// states that otherwise look authorized).
        public static func authorizedIDFA() -> String? {
            guard isEnabled else {
                log("authorizedIDFA -> nil (module disabled)")
                return nil
            }

            guard status == .authorized else {
                log("authorizedIDFA -> nil (status: \(status.name))")
                return nil
            }

            #if canImport(AdSupport)
                let identifier = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                guard identifier != zeroIDFA else {
                    log("authorizedIDFA -> nil (all-zero IDFA)")
                    return nil
                }
                // Returned uppercase, Apple's canonical form. The backend compares this
                // byte-for-byte against the IDFA captured by the click-time macro, so the
                // casing must not be normalised here.
                return identifier
            #else
                return nil
            #endif
        }

        /// Stable status name for the core SDK, so `ATTrackingManager.AuthorizationStatus`
        /// never crosses the module boundary.
        public static func authorizationStatusName() -> String {
            status.name
        }

        // MARK: - Helpers

        private static func hasUsageDescription() -> Bool {
            guard let value = Bundle.main.object(forInfoDictionaryKey: usageDescriptionKey) as? String else {
                return false
            }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        private static func log(_ message: String) {
            guard debugLogging else { return }
            print("[PaylisherATT] \(message)")
        }
    }

#endif
