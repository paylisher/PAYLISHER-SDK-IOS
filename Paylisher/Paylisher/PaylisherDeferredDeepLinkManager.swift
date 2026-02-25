//
//  PaylisherDeferredDeepLinkManager.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation

/**
 * Manager for deferred deep link attribution.
 *
 * Deferred deep linking enables attribution of app installs to marketing campaigns.
 * When a user clicks a deep link but doesn't have the app installed, they are sent
 * to the App Store. After installation, on first app launch, this manager checks
 * if the install should be attributed to a previous deep link click.
 *
 * Flow:
 * 1. User clicks deep link (e.g., Instagram ad)
 * 2. Backend records click with device fingerprint
 * 3. User redirected to App Store
 * 4. User installs app
 * 5. On first launch, this manager:
 *    - Detects first launch
 *    - Generates device fingerprint
 *    - Checks backend for matching click
 *    - If match found, navigates to deep link destination
 *    - Sets JID for attribution tracking
 *
 * Thread Safety:
 * - All public methods are thread-safe
 * - Callbacks are executed on main thread
 * - Network calls are executed on background thread
 *
 * Example Usage:
 * ```swift
 * // In AppDelegate.application(_:didFinishLaunchingWithOptions:)
 * PaylisherDeferredDeepLinkManager.check(
 *     config: config,
 *     deferredConfig: deferredConfig,
 *     onSuccess: { deepLink in
 *         print("Deferred match: \(deepLink.url)")
 *         // SDK will auto-handle if autoHandleDeepLink = true
 *     },
 *     onNoMatch: {
 *         print("No deferred match found")
 *     },
 *     onError: { error in
 *         print("Error: \(error)")
 *     }
 * )
 * ```
 */
public class PaylisherDeferredDeepLinkManager {

    // MARK: - Properties

    private let config: PaylisherDeferredDeepLinkConfig
    private let apiKey: String
    private let sdkVersion: String

    private let firstLaunchDetector: PaylisherFirstLaunchDetector
    private let deviceFingerprint: PaylisherDeviceFingerprint
    private let deferredDeepLinkAPI: PaylisherDeferredDeepLinkAPI
    private let journeyContext: PaylisherJourneyContext

    private let lock = NSLock()
    private var isChecking = false
    private var hasChecked = false

    // MARK: - Singleton

    private static var instance: PaylisherDeferredDeepLinkManager?

    // MARK: - Initialization

    private init(
        config: PaylisherDeferredDeepLinkConfig,
        apiKey: String,
        sdkVersion: String
    ) {
        self.config = config
        self.apiKey = apiKey
        self.sdkVersion = sdkVersion

        self.firstLaunchDetector = PaylisherFirstLaunchDetector.shared
        self.deviceFingerprint = PaylisherDeviceFingerprint()
        self.deferredDeepLinkAPI = PaylisherDeferredDeepLinkAPI(
            apiKey: apiKey,
            sdkVersion: sdkVersion,
            deferredDeepLinkHost: config.deferredDeepLinkAPIHost,
            timeout: config.apiTimeout
        )
        self.journeyContext = PaylisherJourneyContext.shared
    }

    // MARK: - Setup

    /**
     * Initializes the Deferred Deep Link Manager.
     *
     * This should be called during SDK initialization if deferred deep linking is enabled.
     *
     * @param config Deferred deep link configuration
     * @param apiKey Paylisher API key
     * @param sdkVersion SDK version string
     */
    public static func setup(
        config: PaylisherDeferredDeepLinkConfig,
        apiKey: String,
        sdkVersion: String
    ) {
        guard instance == nil else {
            hedgeLog("[PaylisherDeferredDeepLink] Manager already initialized")
            return
        }

        instance = PaylisherDeferredDeepLinkManager(
            config: config,
            apiKey: apiKey,
            sdkVersion: sdkVersion
        )

        hedgeLog("[PaylisherDeferredDeepLink] Manager initialized")
    }

    /**
     * Checks if the manager is setup.
     */
    public static func isSetup() -> Bool {
        return instance != nil
    }

    /**
     * Gets the singleton instance.
     *
     * @throws Runtime error if not setup
     */
    public static func getInstance() -> PaylisherDeferredDeepLinkManager {
        guard let instance = instance else {
            fatalError("PaylisherDeferredDeepLinkManager not setup. Call setup() first.")
        }
        return instance
    }

    // MARK: - Check for Deferred Deep Link

    /**
     * Checks for a deferred deep link match.
     *
     * This method:
     * 1. Verifies this is the first app launch
     * 2. Generates device fingerprint
     * 3. Queries backend for matching click
     * 4. Invokes appropriate callback
     * 5. Optionally auto-handles deep link
     *
     * Important:
     * - This should be called during app initialization (application:didFinishLaunchingWithOptions:)
     * - It will only check once per app lifetime
     * - Network call is asynchronous
     * - All callbacks are executed on main thread
     *
     * @param onSuccess Called when a match is found. Receives the deferred deep link.
     * @param onNoMatch Called when no match is found (normal first install).
     * @param onError Called when an error occurs (network, parsing, etc.).
     */
    public func check(
        onSuccess: @escaping (PaylisherDeepLink) -> Void,
        onNoMatch: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        // Prevent duplicate checks
        lock.lock()
        if hasChecked || isChecking {
            lock.unlock()
            if config.debugLogging {
                hedgeLog("[PaylisherDeferredDeepLink] Already checked or checking, skipping")
            }
            DispatchQueue.main.async {
                onNoMatch()
            }
            return
        }
        isChecking = true
        lock.unlock()

        if config.debugLogging {
            hedgeLog("[PaylisherDeferredDeepLink] Starting check...")
        }

        // Check if this is first launch
        let isFirstLaunch = firstLaunchDetector.isFirstLaunch()

        if !isFirstLaunch {
            if config.debugLogging {
                hedgeLog("[PaylisherDeferredDeepLink] Not first launch, skipping")
            }
            lock.lock()
            isChecking = false
            hasChecked = true
            lock.unlock()

            DispatchQueue.main.async {
                onNoMatch()
            }
            return
        }

        if config.debugLogging {
            hedgeLog("[PaylisherDeferredDeepLink] First launch detected")
        }

        // Generate device fingerprint and check backend (async)
        Task {
            do {
                // Generate deferred deep link fingerprint V1 (matches backend algorithm)
                // IMPORTANT: This uses ONLY publicly available device info (no IDFV/IDFA)
                // to match the fingerprint generated by backend at click-time
                let fingerprint = deviceFingerprint.generateDeferredFingerprintV1()

                if config.debugLogging {
                    hedgeLog("[PaylisherDeferredDeepLink] Fingerprint V1 generated: \(fingerprint.prefix(16))...")
                }

                // Check backend for match
                try await checkBackend(
                    fingerprint: fingerprint,
                    onSuccess: onSuccess,
                    onNoMatch: onNoMatch,
                    onError: onError
                )
            } catch {
                lock.lock()
                isChecking = false
                hasChecked = true
                lock.unlock()

                hedgeLog("[PaylisherDeferredDeepLink] Error: \(error.localizedDescription)")

                DispatchQueue.main.async {
                    onError(error)
                }
            }
        }
    }

    // MARK: - Backend Check

    /**
     * Checks backend API for deferred deep link match.
     */
    private func checkBackend(
        fingerprint: String,
        onSuccess: @escaping (PaylisherDeepLink) -> Void,
        onNoMatch: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async throws {
        if config.debugLogging {
            hedgeLog("[PaylisherDeferredDeepLink] Checking backend...")
        }

        do {
            let response = try await deferredDeepLinkAPI.check(fingerprint: fingerprint)

            lock.lock()
            isChecking = false
            hasChecked = true
            lock.unlock()

            if response.isMatch() {
                await handleMatch(
                    response: response,
                    onSuccess: onSuccess,
                    onError: onError
                )
            } else {
                if config.debugLogging {
                    hedgeLog("[PaylisherDeferredDeepLink] No match found")
                }
                captureNoMatchEvent()

                DispatchQueue.main.async {
                    onNoMatch()
                }
            }
        } catch {
            lock.lock()
            isChecking = false
            hasChecked = true
            lock.unlock()

            hedgeLog("[PaylisherDeferredDeepLink] API error: \(error.localizedDescription)")
            captureErrorEvent(error: error)

            throw error
        }
    }

    // MARK: - Match Handling

    /**
     * Handles successful deferred deep link match.
     */
    private func handleMatch(
        response: PaylisherDeferredDeepLinkResponse,
        onSuccess: @escaping (PaylisherDeepLink) -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        if config.debugLogging {
            hedgeLog("[PaylisherDeferredDeepLink] Match found!")
            hedgeLog("  URL: \(response.url ?? "nil")")
            hedgeLog("  Campaign: \(response.campaignKey ?? "nil")")
            hedgeLog("  JID: \(response.jid ?? "nil")")
        }

        guard let deepLinkURL = response.url else {
            DispatchQueue.main.async {
                onError(DeferredDeepLinkError.matchFoundButURLIsNil)
            }
            return
        }

        // Parse deep link URL and enrich with campaign parameters if missing
        guard var urlComponents = URLComponents(string: deepLinkURL) else {
            DispatchQueue.main.async {
                onError(DeferredDeepLinkError.failedToParseURL)
            }
            return
        }

        // Ensure keyName and jid are in the URL for proper tracking
        var queryItems = urlComponents.queryItems ?? []

        // Add keyName if not present and we have campaignKey from response
        if let campaignKey = response.campaignKey,
           !campaignKey.isEmpty,
           !queryItems.contains(where: { $0.name == "keyName" || $0.name == "key" || $0.name == "k" }) {
            queryItems.append(URLQueryItem(name: "keyName", value: campaignKey))
            if config.debugLogging {
                hedgeLog("[PaylisherDeferredDeepLink] Added keyName=\(campaignKey) to URL")
            }
        }

        // Add jid if not present and we have jid from response
        if let jid = response.jid,
           !jid.isEmpty,
           !queryItems.contains(where: { $0.name == "jid" }) {
            queryItems.append(URLQueryItem(name: "jid", value: jid))
            if config.debugLogging {
                hedgeLog("[PaylisherDeferredDeepLink] Added jid=\(jid) to URL")
            }
        }

        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = urlComponents.url else {
            DispatchQueue.main.async {
                onError(DeferredDeepLinkError.failedToParseURL)
            }
            return
        }

        if config.debugLogging {
            hedgeLog("[PaylisherDeferredDeepLink] Enriched URL: \(url.absoluteString)")
        }

        guard let deepLink = PaylisherDeepLinkManager.shared.parseURL(url) else {
            DispatchQueue.main.async {
                onError(DeferredDeepLinkError.failedToParseURL)
            }
            return
        }

        // Set JID from backend (high priority)
        if let jid = response.jid {
            journeyContext.setJourneyId(jid, source: .deferredDeeplink)

            if config.debugLogging {
                hedgeLog("[PaylisherDeferredDeepLink] JID set: \(jid)")
            }
        }

        // Capture attribution event
        captureAttributionEvent(response: response, deepLink: deepLink)

        // Invoke success callback on main thread
        DispatchQueue.main.async {
            onSuccess(deepLink)
        }

        // Auto-handle deep link if enabled
        if config.autoHandleDeepLink {
            autoHandleDeferredDeepLink(deepLink)
        }
    }

    /**
     * Automatically handles deferred deep link by passing it to DeepLinkManager.
     */
    private func autoHandleDeferredDeepLink(_ deepLink: PaylisherDeepLink) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if PaylisherDeepLinkManager.isConfigured() {
                if self.config.debugLogging {
                    hedgeLog("[PaylisherDeferredDeepLink] Auto-handling deep link")
                }

                // Let DeepLinkManager handle it (campaign resolution, auth, etc.)
                _ = PaylisherDeepLinkManager.shared.handleURL(deepLink.url)
            } else {
                hedgeLog("[PaylisherDeferredDeepLink] DeepLinkManager not configured, cannot auto-handle")
            }
        }
    }

    // MARK: - Analytics Events

    /**
     * Captures install attribution event when match is found.
     */
    private func captureAttributionEvent(
        response: PaylisherDeferredDeepLinkResponse,
        deepLink: PaylisherDeepLink
    ) {
        var properties: [String: Any] = [
            "url": response.url ?? "",
            "campaign_key": response.campaignKey ?? "",
            "jid": response.jid ?? "",
            "source": "deferred_deeplink",
            "destination": deepLink.destination,
            "is_first_launch": true
        ]

        // Add attribution window
        if let window = response.attributionWindow {
            properties["attribution_window_seconds"] = window
        }

        // Add click timestamp
        if let timestamp = response.clickTimestamp {
            properties["click_timestamp"] = timestamp
        }

        // Add metadata
        if let metadata = response.metadata {
            let metadataDict = metadata.mapValues { $0.value }
            properties["metadata"] = metadataDict
        }

        // Add additional properties from config
        properties.merge(config.additionalEventProperties) { (_, new) in new }

        // ⭐ AUTOMATIC SESSION PROPERTY: Set deeplink_key as session property
        // This enables User Path filtering in Paylisher analytics
        // The session property persists for the entire session, allowing:
        // - Session-level filtering by campaign key
        // - Proper user journey tracking starting from deferred deeplink
        // - Attribution of all session events to the campaign
        if let campaignKey = response.campaignKey, !campaignKey.isEmpty {
            properties["$set_once"] = [
                "deeplink_key": campaignKey
            ]

            if config.debugLogging {
                hedgeLog("[PaylisherDeferredDeepLink] Setting session property: deeplink_key = \(campaignKey)")
            }
        }

        // Capture event
        PaylisherSDK.shared.capture(
            "Deferred Deep Link Match",
            properties: properties
        )

        if config.debugLogging {
            hedgeLog("[PaylisherDeferredDeepLink] Captured attribution event")
        }
    }

    /**
     * Captures event when no match is found (normal install).
     */
    private func captureNoMatchEvent() {
        var properties: [String: Any] = [
            "is_first_launch": true,
            "status": "no_match"
        ]

        properties.merge(config.additionalEventProperties) { (_, new) in new }

        PaylisherSDK.shared.capture(
            "Deferred Deep Link Check",
            properties: properties
        )
    }

    /**
     * Captures event when error occurs.
     */
    private func captureErrorEvent(error: Error) {
        var properties: [String: Any] = [
            "is_first_launch": true,
            "status": "error",
            "error_message": error.localizedDescription
        ]

        if let apiError = error as? PaylisherDeferredDeepLinkAPIError {
            properties["error_type"] = String(describing: apiError)
        }

        properties.merge(config.additionalEventProperties) { (_, new) in new }

        PaylisherSDK.shared.capture(
            "Deferred Deep Link Error",
            properties: properties
        )
    }

    // MARK: - Testing

    /**
     * Resets the check state (for testing only).
     *
     * ⚠️ WARNING: This is for testing purposes only!
     */
    public func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }

        isChecking = false
        hasChecked = false
        firstLaunchDetector.reset()
    }

    // MARK: - Convenience Static Methods

    /**
     * Convenience method to check for deferred deep link.
     *
     * This can be called directly without getting the instance first.
     *
     * @param config Deferred deep link configuration
     * @param apiKey Paylisher API key
     * @param sdkVersion SDK version
     * @param onSuccess Success callback
     * @param onNoMatch No match callback
     * @param onError Error callback
     */
    public static func check(
        config: PaylisherDeferredDeepLinkConfig,
        apiKey: String,
        sdkVersion: String,
        onSuccess: @escaping (PaylisherDeepLink) -> Void,
        onNoMatch: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard config.enabled else {
            if config.debugLogging {
                hedgeLog("[PaylisherDeferredDeepLink] Disabled in config")
            }
            onNoMatch()
            return
        }

        // Setup if not already
        if !isSetup() {
            setup(config: config, apiKey: apiKey, sdkVersion: sdkVersion)
        }

        // Check for deferred deep link
        getInstance().check(
            onSuccess: onSuccess,
            onNoMatch: onNoMatch,
            onError: onError
        )
    }
}

// MARK: - Error Types

enum DeferredDeepLinkError: LocalizedError {
    case fingerprintGenerationFailed
    case matchFoundButURLIsNil
    case failedToParseURL

    var errorDescription: String? {
        switch self {
        case .fingerprintGenerationFailed:
            return "Failed to generate device fingerprint"
        case .matchFoundButURLIsNil:
            return "Deferred deep link match found but URL is nil"
        case .failedToParseURL:
            return "Failed to parse deferred deep link URL"
        }
    }
}
