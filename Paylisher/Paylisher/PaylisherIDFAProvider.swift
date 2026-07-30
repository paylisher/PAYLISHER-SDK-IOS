//
//  PaylisherIDFAProvider.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation

/**
 * Injection seam for the advertising identifier (IDFA).
 *
 * WHY THIS EXISTS
 * ---------------
 * The core SDK deliberately contains NO `AdSupport` / `AppTrackingTransparency` code. Not
 * disabled at runtime — absent from the binary. `strings`/`nm` over the shipped framework
 * returns zero hits for `ASIdentifierManager`, `advertisingIdentifier`, `ATTrackingManager`
 * and `AdSupport`.
 *
 * That is a hard requirement, not a preference. App Review's App Tracking Transparency check
 * is a BINARY SYMBOL SCAN, and it rejects in both directions:
 *
 *   - Guideline 2.5.1 — "your app's binary contains references to App Tracking Transparency,
 *     but you have indicated you do not intend to ask users for permission to track."
 *   - Guideline 2.1 — "The app uses the AppTrackingTransparency framework, but we are unable
 *     to locate the App Tracking Transparency permission request."
 *
 * A runtime `enabled = false` flag does not remove a symbol, so it cannot satisfy either
 * check. The only durable fix is for the symbols not to be there. Apps that want the
 * IDFA-exact attribution layer link the separate, optional `PaylisherATT` module and call
 * `PaylisherATT.enable()`, which registers a provider here.
 *
 * This mirrors what the ecosystem already does: Firebase isolates IDFA in a tiny
 * `GoogleAppMeasurementIdentitySupport` shim, and AppsFlyer ships a `Strict`
 * (`AFSDK_NO_IDFA`) build with its own downgraded privacy manifest.
 */
public protocol PaylisherIDFAProviding {
    /**
     * Returns the IDFA ONLY when ATT authorization has ALREADY been granted.
     *
     * Implementations MUST read the current authorization status and MUST NEVER call
     * `requestTrackingAuthorization`. The SDK never shows a permission prompt of its own —
     * that call belongs to the host app, which owns the timing and the on-boarding copy.
     *
     * Return `nil` when authorization is not granted, when the user opted out, or for the
     * all-zero IDFA.
     */
    static func authorizedIDFA() -> String?

    /**
     * Current ATT authorization status as a stable lowercase string:
     * `notDetermined` / `restricted` / `denied` / `authorized` / `unavailable`.
     *
     * Returned as a String on purpose: it keeps `ATTrackingManager.AuthorizationStatus` —
     * and therefore the `AppTrackingTransparency` symbol — out of the core module's
     * signatures.
     */
    static func authorizationStatusName() -> String
}

/**
 * Core-side registry for an optional `PaylisherIDFAProviding` implementation.
 *
 * With no provider registered (the default, and the only possibility when the `PaylisherATT`
 * module is not linked) every accessor returns the "no identifier, status unavailable"
 * answer, and the SDK behaves exactly as it does today for a non-consenting user: attribution
 * falls back to the non-identifying device hash.
 */
public enum PaylisherIDFA {
    /// Status reported when no provider is registered or ATT is unavailable on this OS.
    public static let statusUnavailable = "unavailable"

    private static let lock = NSLock()
    private static var provider: PaylisherIDFAProviding.Type?

    /// Installs the provider. Called by `PaylisherATT.enable()`; hosts do not call this directly.
    public static func register(_ provider: PaylisherIDFAProviding.Type) {
        lock.withLock { self.provider = provider }
        hedgeLog("[PaylisherIDFA] Provider registered — IDFA layer available")
    }

    /// Removes the provider. After this call the SDK can no longer read an advertising
    /// identifier, which is the runtime kill-switch for an app that already links the module.
    public static func unregister() {
        lock.withLock { provider = nil }
        hedgeLog("[PaylisherIDFA] Provider unregistered — IDFA layer disabled")
    }

    /// Whether an IDFA provider is currently registered.
    public static var isAvailable: Bool {
        lock.withLock { provider != nil }
    }

    /// The already-authorized IDFA, or `nil`. Never prompts — see `PaylisherIDFAProviding`.
    static func authorizedIDFA() -> String? {
        let current = lock.withLock { provider }
        return current?.authorizedIDFA()
    }

    /// ATT status name, or `unavailable` when no provider is registered.
    static func authorizationStatusName() -> String {
        let current = lock.withLock { provider }
        return current?.authorizationStatusName() ?? statusUnavailable
    }
}
