//
//  PaylisherDeepLinkManager.swift
//  Paylisher
//
//  Created by Yusuf Uluşahin on 24.12.2025.
//


import Foundation

#if os(iOS)
import UIKit
#endif

// MARK: - Deep Link Result

/// Represents a parsed deep link
@objc(PaylisherDeepLink) public class PaylisherDeepLink: NSObject {
    
    /// Original URL
    @objc public let url: URL
    
    /// URL Scheme (e.g., "myapp" or "https")
    @objc public let scheme: String
    
    /// Destination/path (e.g., "wallet", "profile")
    @objc public let destination: String
    
    /// Query parameters as dictionary
    @objc public let parameters: [String: String]
    
    /// Whether authentication is required (from URL param)
    @objc public let authParamRequired: Bool
    
    /// Campaign ID if present
    @objc public let campaignId: String?
    
    /// Source parameter if present
    @objc public let source: String?

    /// Journey ID (jid) for campaign attribution
    @objc public let jid: String?

    /// Timestamp when deep link was received
    @objc public let timestamp: Date

    /// Raw query string
    @objc public let rawQuery: String?

    /// Campaign key name extracted from URL (if present)
    @objc public let campaignKeyName: String?

    /// Resolved campaign data from backend (if available)
    public var campaignData: PaylisherResolvedDeepLinkPayload?

    init(url: URL,
         scheme: String,
         destination: String,
         parameters: [String: String],
         authParamRequired: Bool,
         campaignId: String?,
         source: String?,
         jid: String?,
         rawQuery: String?,
         campaignKeyName: String?) {
        self.url = url
        self.scheme = scheme
        self.destination = destination
        self.parameters = parameters
        self.authParamRequired = authParamRequired
        self.campaignId = campaignId
        self.source = source
        self.jid = jid
        self.timestamp = Date()
        self.rawQuery = rawQuery
        self.campaignKeyName = campaignKeyName
        super.init()
    }
    
    /// Whether this is a short link from link.usepublisher.com that requires backend resolution
    @objc public var isShortLink: Bool {
        return url.host == "link.usepublisher.com"
    }

    /// The effective navigation destination.
    /// For short links (link.usepublisher.com), returns the host from the resolved iosUrl (e.g. "profile").
    /// Falls back to the raw `destination` when campaignData is not yet available.
    @objc public var resolvedDestination: String {
        if let iosUrl = campaignData?.iosUrl,
           !iosUrl.isEmpty,
           let resolved = URL(string: iosUrl) {
            if resolved.scheme == "https" || resolved.scheme == "http" {
                let path = resolved.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return path.isEmpty ? destination : path
            } else {
                // Custom scheme URL: use host as route (e.g. "diyetim://profile" → "profile")
                return resolved.host ?? destination
            }
        }
        return destination
    }

    public override var description: String {
        return "PaylisherDeepLink(destination: \(destination), resolvedDestination: \(resolvedDestination), scheme: \(scheme), params: \(parameters))"
    }
}

// MARK: - Deep Link Handler Protocol

/// Protocol for handling deep link callbacks
@objc(PaylisherDeepLinkHandler) public protocol PaylisherDeepLinkHandler: AnyObject {
    
    /// Called when a deep link is received and parsed
    /// - Parameters:
    ///   - deepLink: The parsed deep link object
    ///   - requiresAuth: Whether authentication is required for this destination
    @objc func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool)
    
    /// Called when authentication is required before navigating
    /// - Parameters:
    ///   - deepLink: The pending deep link
    ///   - completion: Call this completion handler after auth success/failure
    @objc optional func paylisherDeepLinkRequiresAuth(_ deepLink: PaylisherDeepLink,
                                                       completion: @escaping (Bool) -> Void)
    
    /// Called when deep link parsing fails
    /// - Parameter url: The URL that failed to parse
    @objc optional func paylisherDeepLinkDidFail(_ url: URL, error: Error?)
}

// MARK: - Deep Link Manager

/// Manages deep link handling for Paylisher SDK
@objc(PaylisherDeepLinkManager) public class PaylisherDeepLinkManager: NSObject {
    
    // MARK: - Singleton
    
    @objc public static let shared = PaylisherDeepLinkManager()

    /// Check if DeepLinkManager is configured
    @objc public static func isConfigured() -> Bool {
        return shared.isInitialized
    }

    // MARK: - Properties
    
    /// Configuration for deep link handling
    @objc public var config: PaylisherDeepLinkConfig = PaylisherDeepLinkConfig()
    
    /// Delegate for deep link callbacks
    @objc public weak var handler: PaylisherDeepLinkHandler?
    
    /// Currently pending deep link (waiting for auth)
    @objc public private(set) var pendingDeepLink: PaylisherDeepLink?
    
    /// Last processed deep link
    @objc public private(set) var lastDeepLink: PaylisherDeepLink?
    
    /// Whether the manager is initialized
    private var isInitialized = false
    
    /// Timer for pending deep link timeout
    private var pendingTimer: Timer?
    
    /// Callback for auth completion
    private var authCompletionCallback: ((Bool) -> Void)?

    /// Deep link that is waiting for a handler to be set
    @objc public private(set) var pendingHandlerDeepLink: PaylisherDeepLink?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    /// Initialize deep link manager with configuration
    @objc public func initialize(config: PaylisherDeepLinkConfig? = nil) {
        if let config = config {
            self.config = config
        }
        isInitialized = true
        log("DeepLinkManager initialized")

        // Check if there is a pending deep link waiting for handler
        if let pending = pendingHandlerDeepLink {
            log("Processing pending deep link that arrived before handler was set: \(pending.destination)")
            // Clear it first to avoid loops if handler calls something that triggers this again (unlikely but safe)
            pendingHandlerDeepLink = nil
            // Process it
            processDeepLink(pending)
        }
    }
    
    // MARK: - Public Methods
    
    /// Handle incoming URL
    /// - Parameter url: The deep link URL to handle
    /// - Returns: True if URL was handled, false otherwise
    @objc @discardableResult
    public func handleURL(_ url: URL) -> Bool {
        guard isInitialized else {
            log("DeepLinkManager not initialized. Call initialize() first.")
            return false
        }
        
        log("Handling URL: \(url.absoluteString)")
        
        // Parse the URL
        guard let deepLink = parseURL(url) else {
            log("Failed to parse URL: \(url.absoluteString)")
            
            // Capture failed event
            if config.captureDeepLinkEvents {
                captureDeepLinkFailedEvent(url, error: nil)
            }
            
            handler?.paylisherDeepLinkDidFail?(url, error: nil)
            return false
        }
        
        // Store last deep link
        lastDeepLink = deepLink

        // If no handler is set, store it as pending
        guard handler != nil else {
            log("Deep link received but no handler set. Storing as pending for when handler is set: \(deepLink.destination)")
            pendingHandlerDeepLink = deepLink
            return true
        }

        // Process directly
        processDeepLink(deepLink)
        return true
    }

    /// Process a parsed deep link
    private func processDeepLink(_ deepLink: PaylisherDeepLink) {
        // ✅ JOURNEY TRACKING: Set jid if present
        if let jid = deepLink.jid {
            PaylisherJourneyContext.shared.setJourneyId(jid, source: .deeplink)
            log("Journey ID set: \(jid)")
        }

        // ✅ SHORT LINK: resolve FIRST, then notify handler (so app gets real destination)
        if let keyName = deepLink.campaignKeyName, deepLink.isShortLink {
            Task {
                await resolveCampaign(for: deepLink, keyName: keyName)

                if self.config.captureDeepLinkEvents {
                    self.captureDeepLinkEvent(deepLink)
                }

                // Notify handler AFTER resolution so campaignData is available
                let requiresAuth = self.isAuthRequired(for: deepLink)
                self.log("Short link resolved - iosUrl: \(deepLink.campaignData?.iosUrl ?? "nil"), notifying handler")

                await MainActor.run {
                    if self.config.autoHandleDeepLinks && requiresAuth {
                        self.setPendingDeepLink(deepLink)
                        if let authHandler = self.handler?.paylisherDeepLinkRequiresAuth {
                            authHandler(deepLink) { [weak self] success in
                                if success { self?.completePendingDeepLink() }
                                else { self?.clearPendingDeepLink() }
                            }
                        }
                    }
                    self.handler?.paylisherDidReceiveDeepLink(deepLink, requiresAuth: requiresAuth)
                }
            }
            return
        }

        // ✅ REGULAR DEEP LINK: resolve async in background, notify handler immediately
        if let keyName = deepLink.campaignKeyName {
            Task {
                await resolveCampaign(for: deepLink, keyName: keyName)

                // Capture "Deep Link Opened" event AFTER campaign resolution
                if self.config.captureDeepLinkEvents {
                    self.captureDeepLinkEvent(deepLink)
                }
            }
        } else {
            // No campaign key - capture event immediately
            if config.captureDeepLinkEvents {
                captureDeepLinkEvent(deepLink)
            }
        }

        // Check if auth is required
        let requiresAuth = isAuthRequired(for: deepLink)

        log("Deep link parsed - destination: \(deepLink.destination), requiresAuth: \(requiresAuth), jid: \(deepLink.jid ?? "none")")

        // Auto handle if enabled
        if config.autoHandleDeepLinks {
            if requiresAuth {
                // Store as pending and request auth
                setPendingDeepLink(deepLink)

                // Notify handler about auth requirement
                if let authHandler = handler?.paylisherDeepLinkRequiresAuth {
                    authHandler(deepLink) { [weak self] success in
                        if success {
                            self?.completePendingDeepLink()
                        } else {
                            self?.clearPendingDeepLink()
                        }
                    }
                }
            }
        }

        // Always notify handler
        handler?.paylisherDidReceiveDeepLink(deepLink, requiresAuth: requiresAuth)
    }
    
    /// Handle URL from SceneDelegate (iOS 13+)
    /// - Parameter urlContexts: URL contexts from scene delegate
    @available(iOS 13.0, *)
    @objc public func handleURLContexts(_ urlContexts: Set<UIOpenURLContext>) {
        guard let url = urlContexts.first?.url else { return }
        handleURL(url)
    }
    
    /// Handle Universal Link from NSUserActivity
    /// - Parameter userActivity: The user activity containing the URL
    /// - Returns: True if handled, false otherwise
    @objc @discardableResult
    public func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        return handleURL(url)
    }
    
    /// Complete pending deep link after successful authentication
    @objc public func completePendingDeepLink() {
        guard let pending = pendingDeepLink else {
            log("No pending deep link to complete")
            return
        }
        
        log("Completing pending deep link: \(pending.destination)")
        
        // Capture completion event
        if config.captureDeepLinkEvents {
            captureDeepLinkCompletedEvent(pending)
        }
        
        // Notify handler
        handler?.paylisherDidReceiveDeepLink(pending, requiresAuth: false)
        
        // Clear pending
        clearPendingDeepLink()
    }
    
    /// Clear pending deep link without completing (internal use)
    @objc public func clearPendingDeepLink() {
        pendingTimer?.invalidate()
        pendingTimer = nil
        pendingDeepLink = nil
        authCompletionCallback = nil
        log("Pending deep link cleared")
    }
    
    /// Cancel pending deep link (user cancelled auth)
    /// This captures a "Deep Link Cancelled" event
    @objc public func cancelPendingDeepLink() {
        guard let pending = pendingDeepLink else {
            log("No pending deep link to cancel")
            return
        }
        
        log("Cancelling pending deep link: \(pending.destination)")
        
        // Capture cancelled event
        if config.captureDeepLinkEvents {
            captureDeepLinkCancelledEvent(pending)
        }
        
        // Clear
        pendingTimer?.invalidate()
        pendingTimer = nil
        pendingDeepLink = nil
        authCompletionCallback = nil
    }
    
    /// Check if there's a pending deep link
    @objc public func hasPendingDeepLink() -> Bool {
        return pendingDeepLink != nil
    }
    
    /// Get pending destination name
    @objc public func getPendingDestination() -> String? {
        return pendingDeepLink?.destination
    }
    
    // MARK: - Parsing
    
    /// Parse URL into PaylisherDeepLink object
    internal func parseURL(_ url: URL) -> PaylisherDeepLink? {
        let scheme = url.scheme ?? ""
        
        // Determine destination based on URL type
        let destination: String
        if scheme == "https" || scheme == "http" {
            // Universal Link: use path
            destination = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            // Custom scheme: use host
            destination = url.host ?? ""
        }
        
        guard !destination.isEmpty else {
            return nil
        }
        
        // Parse query parameters
        var parameters: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                parameters[item.name] = item.value ?? ""
            }
        }
        
        // Extract common parameters
        let authParam = parameters["auth"]
        let authRequired = authParam?.lowercased() == "required"
        let campaignId = parameters["campaign"] ?? parameters["campaign_id"] ?? parameters["utm_campaign"]
        let source = parameters["source"] ?? parameters["utm_source"]
        let jid = parameters["jid"] // ✅ Journey ID for campaign attribution

        // Extract campaign key name using PaylisherDeepLinkTracker's helper
        let campaignKeyName = extractCampaignKey(from: url)

        return PaylisherDeepLink(
            url: url,
            scheme: scheme,
            destination: destination,
            parameters: parameters,
            authParamRequired: authRequired,
            campaignId: campaignId,
            source: source,
            jid: jid,
            rawQuery: url.query,
            campaignKeyName: campaignKeyName
        )
    }
    
    // MARK: - Campaign Resolution

    /// Resolve campaign data from backend using campaign key
    private func resolveCampaign(for deepLink: PaylisherDeepLink, keyName: String) async {
        do {
            log("Resolving campaign: \(keyName)")

            let campaignData = try await PaylisherCampaignAPI.resolve(keyName: keyName)
            deepLink.campaignData = campaignData

            log("Campaign resolved successfully: \(campaignData.title ?? "Unknown")")

            // Track resolved campaign
            PaylisherDeepLinkTracker.shared.logResolved(
                url: deepLink.url,
                source: deepLink.scheme,
                resolved: campaignData
            )

            // If jid exists in campaign data, update journey context
            if let jid = campaignData.jid {
                PaylisherJourneyContext.shared.setJourneyId(jid, source: .campaignResolution)
                log("Journey ID updated from campaign: \(jid)")
            }

        } catch {
            log("Failed to resolve campaign: \(error.localizedDescription)")

            // Track resolution failure
            PaylisherDeepLinkTracker.shared.logResolutionFailed(
                url: deepLink.url,
                source: deepLink.scheme,
                keyName: keyName,
                error: error
            )
        }
    }

    // MARK: - Campaign Key Extraction

    /// Extract campaign key from URL
    /// Supports: ?keyName=XXX, ?key=XXX, ?k=XXX, /campaign/XXX, /c/XXX, or single path component
    private func extractCampaignKey(from url: URL) -> String? {
        // 1️⃣ Query parameters
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            if let value = items.first(where: { $0.name == "keyName" })?.value, !value.isEmpty {
                return value
            }
            if let value = items.first(where: { $0.name == "key" })?.value, !value.isEmpty {
                return value
            }
            if let value = items.first(where: { $0.name == "k" })?.value, !value.isEmpty {
                return value
            }
        }

        // 2️⃣ Path components
        let pathParts = url.pathComponents.filter { $0 != "/" }

        // /campaign/XXX
        if let index = pathParts.firstIndex(of: "campaign"),
           pathParts.count > index + 1 {
            let key = pathParts[index + 1]
            if !key.isEmpty {
                return key
            }
        }

        // /c/XXX
        if let index = pathParts.firstIndex(of: "c"),
           pathParts.count > index + 1 {
            let key = pathParts[index + 1]
            if !key.isEmpty {
                return key
            }
        }

        // 3️⃣ Single path component
        if pathParts.count == 1 {
            let potentialKey = pathParts[0]
            // Short link domain (e.g. https://link.usepublisher.com/nARvW): accept any non-empty key
            if let host = url.host, host == "link.usepublisher.com" {
                return potentialKey
            }
            // General case: require at least 4 characters to avoid false positives
            if potentialKey.count >= 4 {
                return potentialKey
            }
        }

        return nil
    }

    // MARK: - Auth Check

    /// Check if authentication is required for the deep link
    private func isAuthRequired(for deepLink: PaylisherDeepLink) -> Bool {
        // Check hardcoded list first (security)
        if config.authRequiredDestinations.contains(deepLink.destination) {
            return true
        }
        
        // Then check URL parameter (flexibility)
        if deepLink.authParamRequired {
            return true
        }
        
        return false
    }
    
    // MARK: - Pending Management
    
    private func setPendingDeepLink(_ deepLink: PaylisherDeepLink) {
        // Clear any existing
        clearPendingDeepLink()
        
        // Set new pending
        pendingDeepLink = deepLink
        
        // Start timeout timer
        pendingTimer = Timer.scheduledTimer(withTimeInterval: config.pendingDeepLinkTimeout,
                                            repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.log("Pending deep link timed out")
            
            // Capture timeout event
            if self.config.captureDeepLinkEvents {
                self.captureDeepLinkTimeoutEvent(deepLink)
            }
            
            self.pendingDeepLink = nil
            self.pendingTimer = nil
            self.authCompletionCallback = nil
        }
        
        log("Pending deep link set: \(deepLink.destination)")
    }
    
    // MARK: - Event Capture
    
    /// Capture "Deep Link Opened" event
    private func captureDeepLinkEvent(_ deepLink: PaylisherDeepLink) {
        var properties: [String: Any] = [
            "destination": deepLink.destination,
            "scheme": deepLink.scheme,
            "full_url": deepLink.url.absoluteString,
            "auth_required": isAuthRequired(for: deepLink)
        ]

        // ✅ Add jid if present (campaign attribution)
        if let jid = deepLink.jid {
            properties["jid"] = jid
        }

        if let campaign = deepLink.campaignId {
            properties["campaign_id"] = campaign
        }

        if let source = deepLink.source {
            properties["source"] = source
        }

        // ✅ Add campaign key name if present
        if let keyName = deepLink.campaignKeyName {
            properties["campaign_key"] = keyName
            properties["has_campaign_key"] = true
        } else {
            properties["has_campaign_key"] = false
        }

        // ✅ Add resolved campaign data if available
        if let campaignData = deepLink.campaignData {
            let campaignProps = campaignData.toPropertiesDictionary()
            properties.merge(campaignProps) { (_, new) in new }
            properties["campaign_resolved"] = true
        } else {
            properties["campaign_resolved"] = false
        }

        // Add all query parameters
        if !deepLink.parameters.isEmpty {
            properties["parameters"] = deepLink.parameters
        }

        // Merge additional properties from config
        for (key, value) in config.additionalEventProperties {
            properties[key] = value
        }

        // ⭐ AUTOMATIC SESSION PROPERTY: Set deeplink_key as session property
        // This enables User Path filtering in Paylisher analytics
        // The session property persists for the entire session, allowing:
        // - Session-level filtering by campaign key
        // - Proper user journey tracking starting from deeplink
        // - No need for manual $set_once in app code
        if let keyName = deepLink.campaignKeyName {
            properties["$set_once"] = [
                "deeplink_key": keyName
            ]
            log("Setting session property: deeplink_key = \(keyName)")
        }

        // Capture event via Paylisher SDK
        PaylisherSDK.shared.capture("Deep Link Opened", properties: properties)

        log("Captured 'Deep Link Opened' event")
    }
    
    /// Capture "Deep Link Completed" event (after successful auth)
    private func captureDeepLinkCompletedEvent(_ deepLink: PaylisherDeepLink) {
        var properties: [String: Any] = [
            "destination": deepLink.destination,
            "scheme": deepLink.scheme,
            "was_pending": true,
            "time_to_complete": Date().timeIntervalSince(deepLink.timestamp)
        ]
        
        if let campaign = deepLink.campaignId {
            properties["campaign_id"] = campaign
        }
        
        // Merge additional properties from config
        for (key, value) in config.additionalEventProperties {
            properties[key] = value
        }
        
        PaylisherSDK.shared.capture("Deep Link Completed", properties: properties)
        
        log("Captured 'Deep Link Completed' event")
    }
    
    /// Capture "Deep Link Failed" event (parsing or handling error)
    private func captureDeepLinkFailedEvent(_ url: URL, error: Error?) {
        var properties: [String: Any] = [
            "url": url.absoluteString,
            "scheme": url.scheme ?? "unknown",
            "failure_reason": "parse_error"
        ]
        
        if let error = error {
            properties["error_message"] = error.localizedDescription
            properties["error_code"] = (error as NSError).code
        }
        
        // Try to extract what we can
        if let host = url.host {
            properties["attempted_destination"] = host
        } else if let path = url.path.components(separatedBy: "/").last, !path.isEmpty {
            properties["attempted_destination"] = path
        }
        
        // Merge additional properties from config
        for (key, value) in config.additionalEventProperties {
            properties[key] = value
        }
        
        PaylisherSDK.shared.capture("Deep Link Failed", properties: properties)
        
        log("Captured 'Deep Link Failed' event")
    }
    
    /// Capture "Deep Link Timeout" event (pending deep link expired)
    private func captureDeepLinkTimeoutEvent(_ deepLink: PaylisherDeepLink) {
        var properties: [String: Any] = [
            "destination": deepLink.destination,
            "scheme": deepLink.scheme,
            "full_url": deepLink.url.absoluteString,
            "timeout_seconds": config.pendingDeepLinkTimeout,
            "waited_seconds": Date().timeIntervalSince(deepLink.timestamp)
        ]
        
        if let campaign = deepLink.campaignId {
            properties["campaign_id"] = campaign
        }
        
        // Merge additional properties from config
        for (key, value) in config.additionalEventProperties {
            properties[key] = value
        }
        
        PaylisherSDK.shared.capture("Deep Link Timeout", properties: properties)
        
        log("Captured 'Deep Link Timeout' event")
    }
    
    /// Capture "Deep Link Cancelled" event (user cancelled auth)
    private func captureDeepLinkCancelledEvent(_ deepLink: PaylisherDeepLink) {
        var properties: [String: Any] = [
            "destination": deepLink.destination,
            "scheme": deepLink.scheme,
            "full_url": deepLink.url.absoluteString,
            "time_before_cancel": Date().timeIntervalSince(deepLink.timestamp)
        ]
        
        if let campaign = deepLink.campaignId {
            properties["campaign_id"] = campaign
        }
        
        // Merge additional properties from config
        for (key, value) in config.additionalEventProperties {
            properties[key] = value
        }
        
        PaylisherSDK.shared.capture("Deep Link Cancelled", properties: properties)
        
        log("Captured 'Deep Link Cancelled' event")
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        if config.debugLogging {
            print("[PaylisherDeepLink] \(message)")
        }
        hedgeLog("[DeepLink] \(message)")
    }
}

// MARK: - Convenience Extensions

public extension PaylisherDeepLinkManager {
    
    /// Quick setup with common auth-required destinations
    @objc func setupWithAuthDestinations(_ destinations: [String]) {
        config.authRequiredDestinations = destinations
        initialize()
    }
    
    /// Check if a specific destination requires auth
    @objc func doesDestinationRequireAuth(_ destination: String) -> Bool {
        return config.authRequiredDestinations.contains(destination)
    }
    
    /// Add a destination to auth-required list
    @objc func addAuthRequiredDestination(_ destination: String) {
        if !config.authRequiredDestinations.contains(destination) {
            config.authRequiredDestinations.append(destination)
        }
    }
    
    /// Remove a destination from auth-required list
    @objc func removeAuthRequiredDestination(_ destination: String) {
        config.authRequiredDestinations.removeAll { $0 == destination }
    }
}
