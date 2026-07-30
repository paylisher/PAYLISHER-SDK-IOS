//
//  PaylisherSKAdNetworkConfig.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation

/// SKAdNetwork 4.0 coarse conversion value.
///
/// Unlike the 6-bit fine value, the coarse value stays meaningful in the second and third
/// postback windows, so it is the only signal that survives past the first two days after
/// install.
@objc(PaylisherSKAdNetworkCoarseValue)
public enum PaylisherSKAdNetworkCoarseValue: Int {
    /// Not specified by the rule. Treated as `low` when handed to Apple, which is Apple's
    /// own neutral default — there is no "unset" coarse value in SKAdNetwork.
    case unset = 0
    case low = 1
    case medium = 2
    case high = 3

    var name: String {
        switch self {
        case .unset: return "unset"
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }
}

/// A conversion value to report to Apple: "the user who installed from an ad turned out to be
/// worth this much."
///
/// Apple never tells you *which* user this was — that is the point of SKAdNetwork. The value
/// is aggregated into the postback Apple sends to the ad network after the measurement window
/// closes.
@objc(PaylisherSKAdNetworkConversion)
public class PaylisherSKAdNetworkConversion: NSObject {
    /// Fine conversion value, 0...63 (6 bits). Values outside the range are clamped.
    ///
    /// Only meaningful during the FIRST postback window (the first two days after install).
    /// Apple drops it afterwards, which is why a rule that only sets a fine value goes silent
    /// on day three.
    @objc public let fineValue: Int

    /// Coarse conversion value. Meaningful in all three windows.
    @objc public let coarseValue: PaylisherSKAdNetworkCoarseValue

    /// Ask Apple to close the current measurement window immediately and send the postback,
    /// rather than waiting for the window to expire.
    ///
    /// Use it when you already know everything you need (for example the user completed the
    /// purchase you were measuring). It trades later signal for faster reporting — once
    /// locked, no further update is accepted for that window.
    @objc public let lockWindow: Bool

    @objc public init(
        fineValue: Int,
        coarseValue: PaylisherSKAdNetworkCoarseValue = .unset,
        lockWindow: Bool = false
    ) {
        self.fineValue = min(max(fineValue, 0), 63)
        self.coarseValue = coarseValue
        self.lockWindow = lockWindow
        super.init()
    }
}

/// Maps one captured event name to the conversion value it should report.
@objc(PaylisherSKAdNetworkRule)
public class PaylisherSKAdNetworkRule: NSObject {
    /// Exact event name as passed to `capture(_:)` — for example `"purchase"` or
    /// `"registration_completed"`. Matching is case-sensitive.
    @objc public let eventName: String

    /// What to report when that event is captured.
    @objc public let conversion: PaylisherSKAdNetworkConversion

    @objc public init(eventName: String, conversion: PaylisherSKAdNetworkConversion) {
        self.eventName = eventName
        self.conversion = conversion
        super.init()
    }

    /// Convenience initializer for the common case.
    @objc public convenience init(
        eventName: String,
        fineValue: Int,
        coarseValue: PaylisherSKAdNetworkCoarseValue = .unset,
        lockWindow: Bool = false
    ) {
        self.init(
            eventName: eventName,
            conversion: PaylisherSKAdNetworkConversion(
                fineValue: fineValue,
                coarseValue: coarseValue,
                lockWindow: lockWindow
            )
        )
    }
}

/**
 * SKAdNetwork configuration. Assign it to `PaylisherConfig.skAdNetworkConfig` to switch the
 * feature on; leave it `nil` (the default) and no SKAdNetwork code ever runs.
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * WHAT SKADNETWORK ACTUALLY DOES
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * SKAdNetwork is Apple's privacy-preserving install attribution. No identifier is read and
 * no ATT permission is involved — Apple itself decides which ad produced the install, then
 * sends a signed postback to the AD NETWORK once the measurement window closes.
 *
 * The SDK's job is only the app-side half:
 *   1. Register the install with Apple on first launch.
 *   2. Report a conversion value (0...63, plus a coarse tier) as the user does valuable
 *      things, so the postback can say how good the install turned out to be.
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * WHAT YOU WILL AND WILL NOT SEE
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * Be clear-eyed about this: Apple sends the postback to the ad network, NOT to Paylisher.
 * Enabling this alone makes the app-side correct and compliant, but no SKAdNetwork numbers
 * appear in the Paylisher dashboard until one of these exists:
 *   - your app's Info.plist carries `NSAdvertisingAttributionReportEndpoint` pointing at a
 *     Paylisher receiver (a host-app key — an SDK cannot set it), or
 *   - the ad network forwards its postbacks to Paylisher, or
 *   - Paylisher pulls aggregated SKAdNetwork metrics from the network's reporting API.
 *
 * Note also that `SKAdNetworkItems` is NOT needed here: that Info.plist key belongs to apps
 * that DISPLAY ads, not to the advertised app being installed.
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * PRIVACY / OPT-OUT
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * Conversion values ride the normal event pipeline, which already stops at the SDK-wide
 * `optOut` flag, so an opted-out user produces no conversion updates. Install registration
 * is gated on the same flag to match. Nothing here reads a device identifier, and this
 * feature adds no entry to the privacy manifest.
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * EXAMPLE
 * ─────────────────────────────────────────────────────────────────────────────────────────
 *     let skan = PaylisherSKAdNetworkConfig()
 *     skan.rules = [
 *         PaylisherSKAdNetworkRule(eventName: "registration_completed",
 *                                  fineValue: 1, coarseValue: .low),
 *         PaylisherSKAdNetworkRule(eventName: "add_to_cart",
 *                                  fineValue: 10, coarseValue: .medium),
 *         PaylisherSKAdNetworkRule(eventName: "purchase",
 *                                  fineValue: 40, coarseValue: .high, lockWindow: true),
 *     ]
 *     config.skAdNetworkConfig = skan
 *
 * Give higher-value events higher fine values: within a window Apple only accepts an
 * INCREASE, so a `purchase` mapped below `add_to_cart` would be silently ignored.
 */
@objc(PaylisherSKAdNetworkConfig)
public class PaylisherSKAdNetworkConfig: NSObject {
    /// Master switch. Set to `false` to keep the config object around while disabling the
    /// feature entirely — equivalent to leaving `PaylisherConfig.skAdNetworkConfig` nil.
    @objc public var enabled: Bool = true

    /// Register the install with Apple on first launch.
    ///
    /// Leave this on. Without registration Apple has no install to attribute, and a
    /// conversion value reported later has nothing to attach to. Turn it off only if
    /// something else in your app already calls SKAdNetwork.
    @objc public var registerOnInstall: Bool = true

    /// Event-name → conversion-value rules. Empty means the SDK registers the install and
    /// reports nothing further.
    ///
    /// When several rules match one event the LAST match wins, so later entries override
    /// earlier ones.
    @objc public var rules: [PaylisherSKAdNetworkRule] = []

    /// Optional programmatic override, consulted BEFORE `rules`.
    ///
    /// Use it when the value depends on event properties rather than the name alone — for
    /// example bucketing revenue into tiers. Return `nil` to fall through to `rules`.
    ///
    /// Called on the thread that captured the event; keep it fast and side-effect free.
    public var conversionValueResolver: ((_ eventName: String, _ properties: [String: Any]) -> PaylisherSKAdNetworkConversion?)?

    /**
     * Pull the conversion-value schema from the Paylisher backend instead of relying only on
     * `rules` above.
     *
     * ON by default, and it is what makes the feature usable: the schema is a marketing
     * decision that changes far more often than the app ships, so hardcoding it means every
     * change waits for App Review and then applies only to users who updated. With this on,
     * the dashboard is the single definition and the postback decoder reads the SAME one, so
     * "40 means purchase" cannot mean two different things in two places.
     *
     * Locally supplied `rules` and `conversionValueResolver` still WIN over the fetched
     * schema — a host that hardcodes something has said something deliberate, and a remote
     * config should never silently override it.
     *
     * Turning this off makes the SDK never contact the backend for SKAdNetwork at all.
     */
    @objc public var useRemoteSchema: Bool = true

    /**
     * Base URL the schema is fetched from, e.g. `https://link.paylisher.com`.
     *
     * Leave nil to reuse `PaylisherDeferredDeepLinkConfig.deferredDeepLinkAPIHost`'s
     * deployment, falling back to Paylisher's SaaS host. Override it for an on-prem or
     * regional deployment — a schema fetched from the SaaS backend would describe a different
     * operator's app, and the conversion values would be meaningless.
     */
    @objc public var configHost: String?

    /// Verbose logging of every SKAdNetwork decision (window, accepted/ignored, Apple errors).
    @objc public var debugLogging: Bool = false

    @objc override public init() {
        super.init()
    }

    /// Swift convenience initializer.
    public convenience init(
        enabled: Bool = true,
        registerOnInstall: Bool = true,
        rules: [PaylisherSKAdNetworkRule] = [],
        debugLogging: Bool = false
    ) {
        self.init()
        self.enabled = enabled
        self.registerOnInstall = registerOnInstall
        self.rules = rules
        self.debugLogging = debugLogging
    }

    /// Resolves the conversion value for a captured event from LOCALLY supplied configuration
    /// only — the host's resolver first, then the host's `rules`.
    ///
    /// Returns nil when neither says anything, which is the signal for the manager to fall
    /// through to the fetched schema. Keeping the remote path out of here is what guarantees
    /// local config always wins.
    func conversion(for eventName: String, properties: [String: Any]) -> PaylisherSKAdNetworkConversion? {
        if let resolved = conversionValueResolver?(eventName, properties) {
            return resolved
        }
        // Last match wins, so a later rule can override an earlier one for the same event.
        return rules.last { $0.eventName == eventName }?.conversion
    }
}
