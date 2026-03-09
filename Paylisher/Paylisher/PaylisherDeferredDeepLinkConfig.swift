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

    /// Enable deferred deep link checking on first launch
    public var enabled: Bool = false

    /// Time window for attributing clicks to installs (default: 24 hours in milliseconds)
    public var attributionWindowMillis: Int64 = Constants.defaultAttributionWindow

    /// Include IDFA in fingerprint (requires ATT authorization)
    public var includeIDFA: Bool = true

    /// Enable verbose logging for debugging
    public var debugLogging: Bool = false

    /// Automatically handle deferred deep link (vs. callback only)
    public var autoHandleDeepLink: Bool = true

    /// Extra properties to add to attribution events
    public var additionalEventProperties: [String: Any] = [:]

    /// Custom deferred deep link API host (optional)
    public var deferredDeepLinkAPIHost: String?

    /// API request timeout (default: 10 seconds)
    public var apiTimeout: TimeInterval = 10.0

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
     * Important: Including IDFA improves attribution accuracy but requires
     * ATT (App Tracking Transparency) authorization on iOS 14.5+.
     * Make sure you have proper authorization before enabling.
     *
     * You must add NSUserTrackingUsageDescription to your Info.plist.
     *
     * @param include Whether to include IDFA in fingerprint
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
     * - Enabled: false (must be explicitly enabled)
     * - Attribution window: 24 hours
     * - Include IDFA: true
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
     * - Include IDFA: true (assumes ATT consent obtained)
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
