//
//  PaylisherDeferredDeepLinkConfig.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation

/**
 * Configuration for deferred deep link attribution.
 *
 * Deferred deep linking allows attribution of app installs to marketing campaigns.
 * When a user clicks a deep link but doesn't have the app installed:
 * 1. They are redirected to App Store
 * 2. After installing, on first launch, SDK checks for deferred deep link
 * 3. If match found, user is automatically directed to the deep link destination
 *
 * Example Use Case:
 * ```
 * User clicks: "Install app and get 50% off"
 * → App Store → Install → First Launch
 * → SDK detects deferred deep link → User taken to promo page
 * → All events tracked with campaign attribution
 * ```
 *
 * Privacy Considerations:
 * - Requires user consent for IDFA collection (iOS 14.5+)
 * - Device fingerprint is hashed before transmission
 * - Attribution window limits how long clicks are tracked
 * - Compliant with Apple's App Tracking Transparency framework
 */
public class PaylisherDeferredDeepLinkConfig {

    // MARK: - Properties

    /// Enable deferred deep link checking on first launch.
    /// DEFAULT ON: every app that sets up the SDK gets deferred deeplink / install attribution on
    /// first launch WITHOUT the host app writing any config (mirrors the Android SDK). A customer
    /// that does not want it opts out explicitly with `enabled = false`.
    /// NOTE: when false, the ENTIRE deferred flow (fingerprint generation + backend match) is skipped.
    public var enabled: Bool = true

    /// Time window for attributing clicks to installs (default: 24 hours in milliseconds)
    public var attributionWindowMillis: Int64 = Constants.defaultAttributionWindow

    /// Attach the advertising identifier (IDFA) to the attribution request when the user has
    /// ALREADY granted App Tracking Transparency authorization.
    ///
    /// Defaults to `false`. Two things are required for an IDFA to actually be sent, and either
    /// one alone turns the feature off completely:
    ///
    ///   1. This flag is `true`, and
    ///   2. the host app links the separate, optional `PaylisherATT` module and calls
    ///      `PaylisherATT.enable()`.
    ///
    /// Without the module the core SDK contains no `AdSupport` / `AppTrackingTransparency`
    /// symbol at all, so this flag has nothing to read and quietly stays a no-op. That is
    /// intentional: App Review's ATT check scans the binary for those symbols, so a build that
    /// merely disables the feature at runtime would still be rejected under Guideline 2.5.1.
    ///
    /// The SDK NEVER shows the ATT permission prompt itself. If you want one, call
    /// `PaylisherATT.requestAuthorization(...)` from your own onboarding flow and add
    /// `NSUserTrackingUsageDescription` to your Info.plist.
    ///
    /// Turning this off does not disable attribution — it falls back to the non-identifying
    /// device fingerprint, which is how every non-consenting user is already attributed today.
    public var includeIDFA: Bool = false

    /// Enable verbose logging for debugging
    public var debugLogging: Bool = false

    /// Automatically handle deferred deep link (vs. callback only)
    public var autoHandleDeepLink: Bool = true

    /// Extra properties to add to attribution events
    public var additionalEventProperties: [String: Any] = [:]

    /// Custom deferred deep link API host (optional)
    public var deferredDeepLinkAPIHost: String?

    /// Hostname that IDFA-bearing attribution requests are sent to, and ONLY those.
    ///
    /// Apple requires an SDK whose privacy manifest sets `NSPrivacyTracking = true` to also list
    /// at least one `NSPrivacyTrackingDomains` entry — App Store Connect rejects the upload
    /// otherwise (ITMS-91064). But from iOS 17 on, the OS FAILS every network request to a listed
    /// tracking domain while ATT is not authorized.
    ///
    /// Those two rules together make a single shared host unusable. `link.paylisher.com` serves
    /// the non-identifying fingerprint lookup as well, so declaring it would take deferred deep
    /// linking down for every user who was never prompted or who declined — almost everyone.
    /// Apple's prescribed answer is hostname separation, which is what every MMP does
    /// (`att.attr.appsflyersdk.com`, `api-safetrack.branch.io`, `safetrack.singular.net`).
    ///
    /// So: requests carrying an IDFA go here, fingerprint-only requests keep going to
    /// `deferredDeepLinkAPIHost`. This value MUST match the domain declared in the `PaylisherATT`
    /// module's privacy manifest.
    ///
    /// Set it to `nil` to guarantee no advertising identifier ever leaves the device, whatever
    /// the other switches say — the SDK then drops the IDFA and sends a fingerprint-only request
    /// rather than sending an identifier to an undeclared host.
    ///
    /// The default points at Paylisher's SaaS tracking host. Only the HOSTNAME is swapped —
    /// scheme, port and path come from `deferredDeepLinkAPIHost` — so if you run an on-prem or
    /// regional deployment and override that, override this too with the matching tracking
    /// subdomain of YOUR deployment, and declare that same domain in the `PaylisherATT` privacy
    /// manifest. Leaving the SaaS default in place while pointing the SDK at another backend
    /// would send identifiers to the wrong operator.
    public var attTrackingHost: String? = "att.link.paylisher.com"

    /// API request timeout (default: 10 seconds)
    public var apiTimeout: TimeInterval = 10.0

    /// Also look for a campaign click on cold starts AFTER the install has been attributed.
    ///
    /// Why this exists: the first-launch-only check assumes the only way a campaign link can
    /// send someone to the App Store is when they do not have the app. That is false. A user
    /// who already has the app reaches the store whenever the bridge cannot open the app scheme
    /// (in-app browsers, iOS Chrome, a missing universal link) or simply taps "Download", and
    /// the store's "Open" button then launches the app with NO url. Everything the campaign was
    /// for — the destination screen and the attribution — is dropped on the floor.
    ///
    /// With this on, a cold start that did NOT arrive through a deep link asks the backend
    /// whether this device has an unclaimed click. Matching is unchanged and still bounded by
    /// the server's attribution window (30 min by default), so only a genuinely recent click
    /// can be found, and a match is reported as a re-engagement — never as an install.
    public var enableReengagementCheck: Bool = true

    /// Minimum gap between two re-engagement checks, in seconds (default: 5 minutes).
    ///
    /// Bounds how often a device can ask, so a user who cold-starts the app all day costs at
    /// most a handful of requests per hour. Lower it only if your campaigns depend on a very
    /// tight click→open loop.
    public var reengagementCheckMinIntervalSeconds: TimeInterval = 300

    /// How long to wait after launch before running the re-engagement check (default: 2.5s).
    ///
    /// A deep-linked launch delivers its url slightly AFTER `didFinishLaunchingWithOptions`
    /// (`scene(_:openURLContexts:)`, `continue userActivity`). Checking immediately would race
    /// that url and could claim the very click the incoming deep link is already handling —
    /// reporting the same open twice. Waiting a moment lets the url arrive first; if one did,
    /// the check is skipped entirely.
    public var reengagementCheckDelaySeconds: TimeInterval = 2.5

    // MARK: - Constants

    public struct Constants {
        /// Default attribution window: 24 hours (86400000 milliseconds)
        /// This is the industry standard attribution window for deferred deep links.
        /// If a user clicks a link and installs the app more than 24 hours later,
        /// the attribution is considered invalid.
        public static let defaultAttributionWindow: Int64 = 24 * 60 * 60 * 1000 // 24 hours

        /// Extended attribution window: 7 days (604800000 milliseconds)
        /// Some campaigns (e.g., email, retargeting) may benefit from a longer window.
        public static let extendedAttributionWindow: Int64 = 7 * 24 * 60 * 60 * 1000 // 7 days

        /// Short attribution window: 1 hour (3600000 milliseconds)
        /// For testing or high-intent campaigns where users install immediately.
        public static let shortAttributionWindow: Int64 = 60 * 60 * 1000 // 1 hour
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Builder Methods

    /**
     * Builder-style method to enable deferred deep linking.
     *
     * @param isEnabled Whether to enable deferred deep link checking
     * @return This config instance for chaining
     */
    @discardableResult
    public func withEnabled(_ isEnabled: Bool = true) -> PaylisherDeferredDeepLinkConfig {
        self.enabled = isEnabled
        return self
    }

    /**
     * Builder-style method to set attribution window.
     *
     * The attribution window determines how long after a click an install
     * can be attributed to that click.
     *
     * Examples:
     * - 1 hour: Constants.shortAttributionWindow
     * - 24 hours: Constants.defaultAttributionWindow
     * - 7 days: Constants.extendedAttributionWindow
     *
     * @param windowMillis Attribution window in milliseconds
     * @return This config instance for chaining
     */
    @discardableResult
    public func withAttributionWindow(_ windowMillis: Int64) -> PaylisherDeferredDeepLinkConfig {
        self.attributionWindowMillis = windowMillis
        return self
    }

    /**
     * Builder-style method to configure IDFA usage.
     *
     * Important: this flag alone is not enough. The IDFA layer also requires the optional
     * `PaylisherATT` module to be linked and enabled — see `includeIDFA` for the full
     * rationale. The core SDK ships without any advertising-identifier code.
     *
     * If you do enable it, the host app is responsible for ATT: add
     * `NSUserTrackingUsageDescription` to your Info.plist and call
     * `PaylisherATT.requestAuthorization(...)` yourself. The SDK never prompts on its own,
     * and it only ever reads an authorization that has already been granted.
     *
     * @param include Whether to attach the IDFA when it is available
     * @return This config instance for chaining
     */
    @discardableResult
    public func withIDFA(_ include: Bool = true) -> PaylisherDeferredDeepLinkConfig {
        self.includeIDFA = include
        return self
    }

    /**
     * Builder-style method to enable debug logging.
     *
     * When enabled, detailed logs will be output for:
     * - Fingerprint generation
     * - API requests/responses
     * - Attribution matching
     * - Deep link handling
     *
     * Recommended: Enable in debug builds, disable in production
     *
     * @param enabled Whether to enable debug logging
     * @return This config instance for chaining
     */
    @discardableResult
    public func withDebugLogging(_ enabled: Bool = true) -> PaylisherDeferredDeepLinkConfig {
        self.debugLogging = enabled
        return self
    }

    /**
     * Builder-style method to configure automatic deep link handling.
     *
     * When enabled (default), SDK will automatically navigate to the deferred deep link
     * destination after checking. When disabled, you'll receive a callback but must
     * handle navigation yourself.
     *
     * @param auto Whether to automatically handle deep link
     * @return This config instance for chaining
     */
    @discardableResult
    public func withAutoHandle(_ auto: Bool = true) -> PaylisherDeferredDeepLinkConfig {
        self.autoHandleDeepLink = auto
        return self
    }

    /**
     * Builder-style method to add additional event properties.
     *
     * These properties will be added to all deferred deep link attribution events.
     *
     * Example:
     * ```swift
     * config.withAdditionalEventProperties([
     *     "environment": "production",
     *     "ab_test_variant": "B"
     * ])
     * ```
     *
     * @param properties Dictionary of additional properties
     * @return This config instance for chaining
     */
    @discardableResult
    public func withAdditionalEventProperties(
        _ properties: [String: Any]
    ) -> PaylisherDeferredDeepLinkConfig {
        self.additionalEventProperties = properties
        return self
    }

    /**
     * Builder-style method to set custom deferred deep link API host.
     *
     * This is useful for testing or if you have a custom backend.
     *
     * @param host Custom API host URL
     * @return This config instance for chaining
     */
    @discardableResult
    public func withAPIHost(_ host: String) -> PaylisherDeferredDeepLinkConfig {
        self.deferredDeepLinkAPIHost = host
        return self
    }

    /**
     * Builder-style method to set API request timeout.
     *
     * @param timeout Timeout in seconds
     * @return This config instance for chaining
     */
    @discardableResult
    public func withAPITimeout(_ timeout: TimeInterval) -> PaylisherDeferredDeepLinkConfig {
        self.apiTimeout = timeout
        return self
    }

    /**
     * Builder-style method to configure the re-engagement check.
     *
     * @param enabled Whether cold starts may look for a recent campaign click after install
     * @param minIntervalSeconds Minimum gap between two such checks
     * @return This config instance for chaining
     */
    @discardableResult
    public func withReengagementCheck(
        _ enabled: Bool = true,
        minIntervalSeconds: TimeInterval? = nil
    ) -> PaylisherDeferredDeepLinkConfig {
        self.enableReengagementCheck = enabled
        if let minIntervalSeconds {
            self.reengagementCheckMinIntervalSeconds = minIntervalSeconds
        }
        return self
    }

    // MARK: - Convenience Methods

    /**
     * Gets attribution window in hours for easier reading.
     *
     * @return Attribution window in hours
     */
    public func getAttributionWindowHours() -> Int64 {
        return attributionWindowMillis / (60 * 60 * 1000)
    }

    /**
     * Gets attribution window in days.
     *
     * @return Attribution window in days
     */
    public func getAttributionWindowDays() -> Int64 {
        return getAttributionWindowHours() / 24
    }

    // MARK: - Factory Methods

    /**
     * Creates a default configuration with standard settings.
     *
     * Default settings:
     * - Enabled: true (ON by default; opt-out via enabled = false)
     * - Attribution window: 24 hours
     * - Include IDFA: false (opt-in; also needs the optional PaylisherATT module)
     * - Debug logging: false
     * - Auto handle: true
     *
     * @return Default configuration
     */
    public static func `default`() -> PaylisherDeferredDeepLinkConfig {
        return PaylisherDeferredDeepLinkConfig()
    }

    /**
     * Creates a configuration optimized for testing/debugging.
     *
     * Test settings:
     * - Enabled: true
     * - Attribution window: 1 hour (faster testing)
     * - Include IDFA: false (no ATT consent needed for testing)
     * - Debug logging: true
     * - Auto handle: true
     *
     * @return Test configuration
     */
    public static func forTesting() -> PaylisherDeferredDeepLinkConfig {
        let config = PaylisherDeferredDeepLinkConfig()
        config.enabled = true
        config.attributionWindowMillis = Constants.shortAttributionWindow
        config.includeIDFA = false
        config.debugLogging = true
        config.autoHandleDeepLink = true
        return config
    }

    /**
     * Creates a configuration for production use.
     *
     * Production settings:
     * - Enabled: true
     * - Attribution window: 24 hours
     * - Include IDFA: true — an explicit request for the IDFA layer. It still only takes
     *   effect if the app links the optional `PaylisherATT` module, calls
     *   `PaylisherATT.enable()`, and the user has already granted ATT authorization.
     *   Without the module this stays a no-op and attribution uses the device fingerprint.
     * - Debug logging: false
     * - Auto handle: true
     *
     * @return Production configuration
     */
    public static func forProduction() -> PaylisherDeferredDeepLinkConfig {
        let config = PaylisherDeferredDeepLinkConfig()
        config.enabled = true
        config.attributionWindowMillis = Constants.defaultAttributionWindow
        config.includeIDFA = true
        config.debugLogging = false
        config.autoHandleDeepLink = true
        return config
    }
}
