//
//  PaylisherConfig+DeepLink.swift
//  Paylisher
//
//  Created by Yusuf Uluşahin on 24.12.2025.
//


import Foundation

// MARK: - PaylisherConfig Deep Link Extension

public extension PaylisherConfig {
    
    /// Deep link configuration
    /// Access via: config.deepLinkConfig
    @objc var deepLinkConfig: PaylisherDeepLinkConfig {
        get {
            return PaylisherDeepLinkManager.shared.config
        }
        set {
            PaylisherDeepLinkManager.shared.config = newValue
        }
    }
    
    /// Enable deep link handling
    /// Convenience property for quick setup
    @objc var enableDeepLinks: Bool {
        get {
            return PaylisherDeepLinkManager.shared.config.autoHandleDeepLinks
        }
        set {
            PaylisherDeepLinkManager.shared.config.autoHandleDeepLinks = newValue
            if newValue {
                PaylisherDeepLinkManager.shared.initialize()
            }
        }
    }
}

// MARK: - Builder Pattern Support

public extension PaylisherConfig {
    
    /// Configure deep links with builder pattern
    /// Example:
    /// ```swift
    /// let config = PaylisherConfig(apiKey: "...")
    ///     .withDeepLinks(authRequired: ["wallet", "profile"])
    /// ```
    @objc func withDeepLinks(authRequired destinations: [String]) -> PaylisherConfig {
        let deepLinkConfig = PaylisherDeepLinkConfig()
        deepLinkConfig.authRequiredDestinations = destinations
        self.deepLinkConfig = deepLinkConfig
        PaylisherDeepLinkManager.shared.initialize()
        return self
    }
    
    /// Configure deep links with full config
    @objc func withDeepLinks(config: PaylisherDeepLinkConfig) -> PaylisherConfig {
        self.deepLinkConfig = config
        PaylisherDeepLinkManager.shared.initialize()
        return self
    }
}
