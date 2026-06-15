//
//  PaylisherConfig+DeepLink.swift
//  Paylisher
//
//  Created by Yusuf Uluşahin on 24.12.2025.
//


import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

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

// MARK: - Closure-based deep link handler (no protocol to implement)

/// Forwards `PaylisherDeepLinkHandler` callbacks to closures registered via
/// `PaylisherSDK.shared.onDeepLink(...)`. Held strongly by PaylisherSDK (setDeepLinkHandler is weak).
final class PaylisherClosureDeepLinkHandler: NSObject, PaylisherDeepLinkHandler {
    var onReceive: ((PaylisherDeepLink, Bool) -> Void)?
    var onAuth: ((PaylisherDeepLink, @escaping (Bool) -> Void) -> Void)?
    var onFail: ((URL, Error?) -> Void)?

    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        onReceive?(deepLink, requiresAuth)
    }

    func paylisherDeepLinkRequiresAuth(_ deepLink: PaylisherDeepLink, completion: @escaping (Bool) -> Void) {
        if let onAuth = onAuth { onAuth(deepLink, completion) } else { completion(true) }
    }

    func paylisherDeepLinkDidFail(_ url: URL, error: Error?) {
        onFail?(url, error)
    }
}

// MARK: - SwiftUI one-line wiring

#if canImport(SwiftUI) && os(iOS)
@available(iOS 14.0, *)
public extension View {
    /// One-line deep link wiring: forwards custom-scheme URLs (`onOpenURL`) and Universal Links
    /// (`onContinueUserActivity`) to the SDK. Replaces manual `.onOpenURL` / `.onContinueUserActivity`.
    func paylisherDeepLinks() -> some View {
        self
            .onOpenURL { url in
                _ = PaylisherSDK.shared.handleDeepLink(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                _ = PaylisherSDK.shared.handleUserActivity(activity)
            }
    }
}
#endif
