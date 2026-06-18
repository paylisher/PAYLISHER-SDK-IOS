//
//  PaylisherDeepLinkConfig.swift
//  Paylisher
//
//  Created by Yusuf Uluşahin on 24.12.2025.
//


import Foundation

/// Deep Link configuration options
@objc(PaylisherDeepLinkConfig) public class PaylisherDeepLinkConfig: NSObject {
    
    /// Enable automatic deep link event capture
    /// When enabled, SDK automatically captures "Deep Link Opened" event
    /// Default: true
    @objc public var captureDeepLinkEvents: Bool = true
    
    /// Enable automatic deep link handling
    /// When enabled, SDK will automatically process incoming deep links
    /// Default: true
    @objc public var autoHandleDeepLinks: Bool = true
    
    /// List of destinations that always require authentication
    /// These destinations will trigger auth flow regardless of URL parameters
    /// Example: ["wallet", "transfer", "profile", "settings"]
    @objc public var authRequiredDestinations: [String] = []
    
    /// Custom URL schemes to handle
    /// Example: ["myapp", "myapp-dev"]
    @objc public var customSchemes: [String] = []
    
    /// Universal Link domains to handle
    /// Example: ["example.com", "www.example.com"]
    @objc public var universalLinkDomains: [String] = []
    
    /// Enable debug logging for deep links
    /// Default: false
    @objc public var debugLogging: Bool = false
    
    /// Timeout for pending deep link (seconds)
    /// After this time, pending deep link will be cleared
    /// Default: 300 (5 minutes)
    @objc public var pendingDeepLinkTimeout: TimeInterval = 300
    
    /// Additional properties to include with every deep link event
    @objc public var additionalEventProperties: [String: Any] = [:]

    /// Automatically register `campaign_key` + `deeplink_key` as SUPER PROPERTIES when a deep
    /// link carrying a campaign key arrives, so ALL events in that session carry them (deeplink
    /// attribution / user-path) — the host app does NOT need to do this. Cleared when a
    /// non-campaign deep link arrives (and on `reset()`). Default: true.
    @objc public var autoRegisterCampaignKeys: Bool = true

    /// Emit verbose diagnostic/funnel events for deep link processing:
    /// `deeplink_received`, `deeplink_resolved`, `deeplink_resolve_failed`, `deeplink_navigation`.
    /// These are for debugging the deep link pipeline (e.g. inspecting why a campaign key did not
    /// resolve) and are SEPARATE from the business event "Deep Link Opened", which is always
    /// governed by `captureDeepLinkEvents`. OFF by default so production event streams stay clean —
    /// turn it on only while diagnosing.
    /// Default: false
    @objc public var captureDeepLinkDiagnostics: Bool = false
}
