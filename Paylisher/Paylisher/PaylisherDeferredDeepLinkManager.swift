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
            attTrackingHost: config.attTrackingHost,
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

        // Should this launch run the attribution check? Unlike the old
        // `isFirstLaunch()` this does not consume the flag — it is only consumed once
        // the backend has actually answered, so a failed request is retried on the
        // next launch instead of silently losing the attribution.
        let shouldCheck = firstLaunchDetector.shouldAttemptDeferredCheck()
        var isReengagement = false

        if !shouldCheck {
            // The install question is settled — but a click can still be waiting. An installed
            // user who tapped a campaign link and came back through the App Store arrives here
            // with no url at all, so this second look is the only way the deep link is ever
            // delivered. Gated, delayed and skipped for deep-linked launches; see
            // `enableReengagementCheck`.
            guard config.enableReengagementCheck,
                  firstLaunchDetector.canAttemptReengagementCheck(
                      minIntervalSeconds: config.reengagementCheckMinIntervalSeconds
                  )
            else {
                if config.debugLogging {
                    hedgeLog("[PaylisherDeferredDeepLink] Attribution check already settled, skipping")
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

            isReengagement = true
            if config.debugLogging {
                hedgeLog("[PaylisherDeferredDeepLink] Install already attributed — running re-engagement check")
            }
        } else if config.debugLogging {
            hedgeLog("[PaylisherDeferredDeepLink] First launch detected")
        }

        // Generate device fingerprint and check backend (async)
        let reengagement = isReengagement
        Task {
            // Let an incoming url win the race. A deep-linked launch delivers its URL just after
            // `didFinishLaunchingWithOptions`, and that url is already producing the open we
            // would otherwise go and claim a second time.
            if reengagement {
                let delay = max(0, config.reengagementCheckDelaySeconds)
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                if PaylisherDeepLinkManager.shared.didHandleDeepLinkSinceLaunch {
                    if config.debugLogging {
                        hedgeLog("[PaylisherDeferredDeepLink] Launch was already deep-linked, skipping re-engagement check")
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

                // Committed: from here a request goes out, so the interval is spent.
                firstLaunchDetector.markReengagementCheckAttempted()
            }

            do {
                // Generate deferred deep link fingerprint V1 (matches backend algorithm)
                // IMPORTANT: This uses ONLY publicly available device info (no IDFV/IDFA)
                // to match the fingerprint generated by backend at click-time
                let fingerprint = deviceFingerprint.generateDeferredFingerprintV1()

                if config.debugLogging {
                    hedgeLog("[PaylisherDeferredDeepLink] Fingerprint V1 generated: \(fingerprint.prefix(16))...")
                }

                // Opportunistic IDFA. Three independent gates must ALL pass, and each one alone
                // is a complete off switch:
                //
                //   1. `PaylisherATT` linked + `PaylisherATT.enable()` called — otherwise no
                //      provider is registered and `PaylisherIDFA` has nothing to read. Apps that
                //      never add the module carry no AdSupport/ATT symbol at all.
                //   2. `config.includeIDFA` — the runtime switch (defaults to false).
                //   3. SDK-wide `optOut` — checked BEFORE the read and before the network call.
                //      This mirrors the Android discipline in `PaylisherAppInstallIntegration`
                //      (`installTypeAllowed()`); relying on capture()-level opt-out is too late,
                //      because this request is not a captured event and would have carried the
                //      identifier of an opted-out user regardless.
                //
                // Even when all three pass, the provider returns nil unless ATT is ALREADY
                // authorized — the SDK never prompts. Without an IDFA we fall back to
                // fingerprint-only, which is the unchanged, still fully working behavior.
                let optedOut = PaylisherSDK.shared.isOptOut()
                let idfaAllowed = config.includeIDFA && !optedOut
                let idfa = idfaAllowed ? PaylisherIDFA.authorizedIDFA() : nil
                if config.debugLogging {
                    if optedOut, config.includeIDFA {
                        hedgeLog("[PaylisherDeferredDeepLink] IDFA suppressed (SDK opted out)")
                    } else {
                        hedgeLog("[PaylisherDeferredDeepLink] IDFA \(idfa != nil ? "attached (ATT authorized)" : "not attached")")
                    }
                }

                // Raw traits behind the hash, for field-level scoring on the backend.
                // Same sources as generateDeferredFingerprintV1(); no identifiers.
                let signals = deviceFingerprint.collectSignals()
                // With-width alternative hash(es): lets the backend match on a narrower key
                // when the landing page emitted the same form as a click-side candidate.
                let candidates = deviceFingerprint.generateFingerprintCandidates()

                // Check backend for match
                try await checkBackend(
                    fingerprint: fingerprint,
                    idfa: idfa,
                    reengagement: reengagement,
                    signals: signals,
                    fingerprintCandidates: candidates,
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
        idfa: String? = nil,
        reengagement: Bool = false,
        signals: PaylisherDeviceSignals? = nil,
        fingerprintCandidates: [String] = [],
        onSuccess: @escaping (PaylisherDeepLink) -> Void,
        onNoMatch: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async throws {
        if config.debugLogging {
            hedgeLog("[PaylisherDeferredDeepLink] Checking backend... (\(reengagement ? "re-engagement" : "install"))")
        }

        do {
            let response = try await deferredDeepLinkAPI.check(
                fingerprint: fingerprint,
                idfa: idfa,
                reengagement: reengagement,
                signals: signals,
                fingerprintCandidates: fingerprintCandidates
            )

            // The backend answered — match or no-match, the INSTALL question is settled and
            // must not be asked again. Only here, never in the failure paths below. A
            // re-engagement check must not touch that flag: it is a recurring question, and
            // its own rate limit was already consumed when the interval gate let it through.
            if !reengagement {
                firstLaunchDetector.markDeferredCheckCompleted()
            }

            lock.lock()
            isChecking = false
            hasChecked = true
            lock.unlock()

            if response.isMatch() {
                await handleMatch(
                    response: response,
                    reengagement: reengagement,
                    onSuccess: onSuccess,
                    onError: onError
                )
            } else {
                if config.debugLogging {
                    hedgeLog("[PaylisherDeferredDeepLink] No match found")
                }
                if !reengagement {
                    // Only the install check reports a no-match. A re-engagement no-match is the
                    // overwhelmingly common case (most cold starts follow no click at all) and
                    // emitting it would bury the event stream in noise.
                    captureNoMatchEvent()
                }

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
            captureErrorEvent(error: error, reengagement: reengagement)

            throw error
        }
    }

    // MARK: - Match Handling

    /**
     * Handles successful deferred deep link match.
     */
    private func handleMatch(
        response: PaylisherDeferredDeepLinkResponse,
        reengagement: Bool = false,
        onSuccess: @escaping (PaylisherDeepLink) -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        if config.debugLogging {
            hedgeLog("[PaylisherDeferredDeepLink] Match found!")
            hedgeLog("  URL: \(response.url ?? "nil")")
            hedgeLog("  Campaign: \(response.campaignKey ?? "nil")")
            hedgeLog("  JID: \(response.jid ?? "nil")")
        }

        // The url can still have landed while the request was in flight. If it did, the user is
        // already being routed to this same campaign by the real deep link, so delivering the match
        // as well would navigate twice and report the open twice. The click row stays consumed on
        // purpose: it belonged to that very tap, and the incoming deep link is already honouring it.
        if reengagement, PaylisherDeepLinkManager.shared.didHandleDeepLinkSinceLaunch {
            if config.debugLogging {
                hedgeLog("[PaylisherDeferredDeepLink] Deep link arrived meanwhile, dropping re-engagement match")
            }
            return
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
        captureAttributionEvent(response: response, deepLink: deepLink, reengagement: reengagement)

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
        deepLink: PaylisherDeepLink,
        reengagement: Bool = false
    ) {
        var properties: [String: Any] = [
            "url": response.url ?? "",
            "campaign_key": response.campaignKey ?? "",
            "jid": response.jid ?? "",
            "source": reengagement ? "deferred_deeplink_reengagement" : "deferred_deeplink",
            "destination": deepLink.destination,
            "is_first_launch": !reengagement
        ]

        // Add attribution window
        if let window = response.attributionWindow {
            properties["attribution_window_seconds"] = window
        }

        // Add click timestamp
        if let timestamp = response.clickTimestamp {
            properties["click_timestamp"] = timestamp
        }

        // Attribution provenance from the backend waterfall (idfa/gaid/token/probabilistic/fingerprint)
        if let method = response.attributionMethod {
            properties["attribution_method"] = method
        }
        if let confidence = response.confidence {
            properties["attribution_confidence"] = confidence
        }

        // Add metadata
        if let metadata = response.metadata {
            let metadataDict = metadata.mapValues { $0.value }
            properties["metadata"] = metadataDict
        }

        // Add additional properties from config
        properties.merge(config.additionalEventProperties) { (_, new) in new }

        // deeplink_key is managed as a session-level super property by the app
        // via register()/unregister(). No person profile write needed.

        // Two different facts, two different events. "Deferred Deep Link Match" MEANS an install
        // was attributed — install reporting counts it — so a device that already had the app
        // must never emit it. The re-engagement event carries the same payload under a name that
        // says what actually happened. The open itself is not reported here either way: the
        // auto-handled deep link produces the regular "Deep Link Opened", exactly as it would
        // have if the app had been opened by the link directly.
        PaylisherSDK.shared.capture(
            reengagement ? "Deferred Deep Link Reengagement" : "Deferred Deep Link Match",
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
    private func captureErrorEvent(error: Error, reengagement: Bool = false) {
        var properties: [String: Any] = [
            "is_first_launch": !reengagement,
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
