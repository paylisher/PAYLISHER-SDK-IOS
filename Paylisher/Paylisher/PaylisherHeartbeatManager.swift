//
//  PaylisherHeartbeatManager.swift
//  Paylisher
//
//  Created by Paylisher SDK on 26.02.2025.
//

import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
#endif

/// Enterprise-grade heartbeat manager for silent push / uninstall detection.
///
/// Responsibilities:
/// - Store and manage FCM token (thread-safe, persistent)
/// - Process incoming silent heartbeat pushes
/// - Send alive acknowledgment to backend within Apple's background execution budget
/// - Dual strategy: dedicated `/heartbeat` endpoint + `$heartbeat_ack` capture event
///
/// Thread Safety:
/// - All mutable state is protected by `NSLock` (consistent with `PaylisherSessionManager`)
/// - URLSession operations are non-blocking and callback-based
///
/// Apple Compliance:
/// - `fetchCompletionHandler` is always called within 25 seconds (Apple limit: ~30s)
/// - Uses `DispatchWorkItem`-based timeout guard to prevent handler leaks
/// - No UI updates performed during silent push (would cause rejection)
///
@objc public class PaylisherHeartbeatManager: NSObject {
    
    // MARK: - Singleton
    
    @objc public static let shared = PaylisherHeartbeatManager()
    
    // MARK: - Constants
    
    /// Apple terminates background tasks at ~30 seconds.
    /// We cap at 25 seconds to guarantee completion handler is called with safety margin.
    private let maxBackgroundExecutionTime: TimeInterval = 25.0
    
    /// Delay before single retry attempt within the timeout budget.
    private let retryDelay: TimeInterval = 3.0
    
    /// Network request timeout for heartbeat calls.
    private let networkTimeout: TimeInterval = 10.0
    
    /// Minimum interval between heartbeat acks to prevent flooding (seconds).
    /// Backend should not send more frequently than this, but SDK enforces as safety net.
    private let minimumHeartbeatInterval: TimeInterval = 30.0
    
    /// Key used in push payload to identify Paylisher silent heartbeat pushes.
    static let heartbeatTypeValue = "SILENT_HEARTBEAT"
    
    /// Key used in push payload for source identification.
    static let sourceKey = "source"
    static let sourceValue = "Paylisher"
    static let typeKey = "type"
    
    // MARK: - Thread-Safe State
    
    private let tokenLock = NSLock()
    private let timestampLock = NSLock()
    private let completionLock = NSLock()
    
    /// In-memory FCM token cache. Also persisted to PaylisherStorage.
    private var _fcmToken: String?
    
    /// Timestamp of last successful heartbeat to prevent flooding.
    private var _lastHeartbeatTimestamp: TimeInterval = 0
    
    /// Guard against concurrent completion handler calls.
    private var _completionHandlerCalled = false
    
    // MARK: - Dependencies (set during SDK setup)
    
    private var config: PaylisherConfig?
    private var api: PaylisherApi?
    private var storage: PaylisherStorage?
    
    // MARK: - Private Init
    
    private override init() {
        super.init()
    }
    
    // MARK: - Configuration
    
    /// Configure the heartbeat manager with SDK dependencies.
    /// Called internally by PaylisherSDK.setup().
    func configure(config: PaylisherConfig, api: PaylisherApi, storage: PaylisherStorage) {
        self.config = config
        self.api = api
        self.storage = storage
        
        // Restore persisted FCM token into memory
        if let persistedToken = storage.getString(forKey: .deviceToken) {
            tokenLock.withLock {
                _fcmToken = persistedToken
            }
            hedgeLog("[Heartbeat] Restored persisted FCM token.")
        }
        
        // Restore last heartbeat timestamp
        if let persistedTimestamp = storage.getString(forKey: .lastHeartbeatTimestamp),
           let timestamp = Double(persistedTimestamp) {
            timestampLock.withLock {
                _lastHeartbeatTimestamp = timestamp
            }
        }
    }
    
    // MARK: - Public API: FCM Token
    
    /// Register FCM token for heartbeat tracking.
    ///
    /// Thread-safe. Caches in memory and persists to PaylisherStorage.
    /// Since backend uses Firebase Admin SDK to send push,
    /// we need the FCM token (not the raw APNs device token).
    ///
    /// - Parameter token: FCM registration token string from
    ///   `Messaging.messaging().token` or `messaging:didReceiveRegistrationToken`
    func setFCMToken(_ token: String) {
        tokenLock.withLock {
            let previousToken = _fcmToken
            _fcmToken = token
            
            // Persist to storage
            storage?.setString(forKey: .deviceToken, contents: token)
            
            if previousToken != token {
                hedgeLog("[Heartbeat] FCM token registered: \(token.prefix(8))...\(token.suffix(4))")
            } else {
                hedgeLog("[Heartbeat] FCM token unchanged, skipping update.")
            }
        }
    }
    
    /// Get the current FCM token (thread-safe).
    func getFCMToken() -> String? {
        var token: String?
        tokenLock.withLock {
            token = _fcmToken
        }
        return token
    }
    
    // MARK: - Public API: Silent Push Handling
    
    /// Determine if a push payload is a Paylisher silent heartbeat.
    ///
    /// Checks for `source == "Paylisher"` and `type == "SILENT_HEARTBEAT"`.
    ///
    /// - Parameter userInfo: The push notification payload.
    /// - Returns: `true` if this is a Paylisher heartbeat push.
    func isPaylisherHeartbeat(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let source = userInfo[PaylisherHeartbeatManager.sourceKey] as? String,
              source == PaylisherHeartbeatManager.sourceValue,
              let type = userInfo[PaylisherHeartbeatManager.typeKey] as? String,
              type == PaylisherHeartbeatManager.heartbeatTypeValue else {
            return false
        }
        return true
    }
    
    /// Process a silent heartbeat push.
    ///
    /// This is the core method. It:
    /// 1. Validates the push payload
    /// 2. Checks rate limiting (minimum interval)
    /// 3. Sends alive ack to backend via dedicated endpoint
    /// 4. Also captures a `$heartbeat_ack` event as fallback
    /// 5. Guarantees `completionHandler` is called within Apple's time limit
    ///
    /// - Parameters:
    ///   - userInfo: The push notification payload.
    ///   - completionHandler: The background fetch completion handler. MUST be called.
    func processHeartbeat(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let config = self.config else {
            hedgeLog("[Heartbeat] ERROR: HeartbeatManager not configured. Calling completionHandler.")
            completionHandler(.failed)
            return
        }
        
        guard config.enableHeartbeat else {
            hedgeLog("[Heartbeat] Heartbeat disabled in config. Ignoring.")
            completionHandler(.noData)
            return
        }
        
        // Rate limiting: prevent flooding
        let now = Date().timeIntervalSince1970
        var shouldThrottle = false
        timestampLock.withLock {
            if now - _lastHeartbeatTimestamp < minimumHeartbeatInterval {
                shouldThrottle = true
            }
        }
        
        if shouldThrottle {
            hedgeLog("[Heartbeat] Rate limited. Minimum interval not elapsed.")
            completionHandler(.noData)
            return
        }
        
        // Reset completion handler guard
        completionLock.withLock {
            _completionHandlerCalled = false
        }
        
        // CRITICAL: Timeout guard
        // Apple terminates background execution at ~30s.
        // We MUST call completionHandler before that.
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.safeCallCompletion(completionHandler, result: .failed, reason: "Timeout reached (\(self?.maxBackgroundExecutionTime ?? 25)s)")
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + maxBackgroundExecutionTime,
            execute: timeoutWorkItem
        )
        
        // Determine app state for payload context
        let appState = resolveAppState()
        
        hedgeLog("[Heartbeat] Processing heartbeat push. App state: \(appState)")
        
        // Strategy 1: Dedicated heartbeat endpoint
        sendHeartbeatToEndpoint(appState: appState) { [weak self] success in
            guard let self = self else { return }
            
            // Cancel the timeout since we're completing
            timeoutWorkItem.cancel()
            
            if success {
                // Update last heartbeat timestamp
                self.timestampLock.withLock {
                    self._lastHeartbeatTimestamp = Date().timeIntervalSince1970
                    self.storage?.setString(
                        forKey: .lastHeartbeatTimestamp,
                        contents: String(self._lastHeartbeatTimestamp)
                    )
                }
                self.safeCallCompletion(completionHandler, result: .newData, reason: "Heartbeat ack sent successfully")
            } else {
                // Retry once within budget
                hedgeLog("[Heartbeat] First attempt failed. Retrying in \(self.retryDelay)s...")
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + self.retryDelay) { [weak self] in
                    guard let self = self else { return }
                    
                    self.sendHeartbeatToEndpoint(appState: appState) { [weak self] retrySuccess in
                        guard let self = self else { return }
                        
                        if retrySuccess {
                            self.timestampLock.withLock {
                                self._lastHeartbeatTimestamp = Date().timeIntervalSince1970
                                self.storage?.setString(
                                    forKey: .lastHeartbeatTimestamp,
                                    contents: String(self._lastHeartbeatTimestamp)
                                )
                            }
                            self.safeCallCompletion(completionHandler, result: .newData, reason: "Heartbeat ack sent (retry)")
                        } else {
                            self.safeCallCompletion(completionHandler, result: .failed, reason: "Heartbeat ack failed after retry")
                        }
                    }
                }
            }
        }
        
        // Strategy 2 (fire-and-forget): Capture event via existing event pipeline
        // This provides a fallback signal even if /heartbeat endpoint is not ready
        captureHeartbeatEvent(userInfo: userInfo)
    }
    
    // MARK: - Internal: Network
    
    /// Send heartbeat acknowledgment to the dedicated backend endpoint.
    private func sendHeartbeatToEndpoint(appState: String, completion: @escaping (Bool) -> Void) {
        guard let api = self.api else {
            hedgeLog("[Heartbeat] ERROR: PaylisherApi not available.")
            completion(false)
            return
        }
        
        let distinctId = config?.storageManager?.getDistinctId() ?? ""
        let token = getFCMToken()
        
        api.heartbeat(
            distinctId: distinctId,
            deviceToken: token,
            appState: appState,
            completion: { success, error in
                if let error = error {
                    hedgeLog("[Heartbeat] Endpoint error: \(error.localizedDescription)")
                }
                completion(success)
            }
        )
    }
    
    /// Capture `$heartbeat_ack` event via the existing Paylisher event pipeline.
    /// This is a fire-and-forget fallback that works even without a dedicated endpoint.
    private func captureHeartbeatEvent(userInfo: [AnyHashable: Any]) {
        let token = getFCMToken()
        
        var properties: [String: Any] = [
            "platform": "ios",
            "sdk_version": paylisherVersion,
            "timestamp": toISO8601String(Date()),
        ]
        
        if let token = token {
            // Only send first 8 and last 4 chars for privacy in event payload
            if token.count > 12 {
                properties["device_token_prefix"] = String(token.prefix(8))
                properties["device_token_suffix"] = String(token.suffix(4))
            }
            properties["has_fcm_token"] = true
        } else {
            properties["has_fcm_token"] = false
        }
        
        // Extract push metadata if present
        if let pushId = userInfo["push_id"] as? String {
            properties["push_id"] = pushId
        }
        
        #if os(iOS) || os(tvOS)
            properties["app_state"] = resolveAppState()
        #endif
        
        PaylisherSDK.shared.capture("$heartbeat_ack", properties: properties)
    }
    
    // MARK: - Internal: Completion Handler Safety
    
    /// Thread-safe wrapper to guarantee completion handler is called exactly once.
    ///
    /// Apple will crash the app if fetchCompletionHandler is called more than once,
    /// and will reject the app if it's never called.
    private func safeCallCompletion(
        _ handler: @escaping (UIBackgroundFetchResult) -> Void,
        result: UIBackgroundFetchResult,
        reason: String
    ) {
        var shouldCall = false
        completionLock.withLock {
            if !_completionHandlerCalled {
                _completionHandlerCalled = true
                shouldCall = true
            }
        }
        
        if shouldCall {
            hedgeLog("[Heartbeat] Completion: \(reason) (result: \(result.rawValue))")
            handler(result)
        } else {
            hedgeLog("[Heartbeat] Completion handler already called. Skipping duplicate: \(reason)")
        }
    }
    
    // MARK: - Internal: App State
    
    /// Resolve the current application state for heartbeat payload context.
    private func resolveAppState() -> String {
        #if os(iOS) || os(tvOS)
            // Must be called on main thread for UIApplication.shared
            if Thread.isMainThread {
                return appStateString(UIApplication.shared.applicationState)
            } else {
                var state: String = "unknown"
                DispatchQueue.main.sync {
                    state = appStateString(UIApplication.shared.applicationState)
                }
                return state
            }
        #else
            return "unsupported_platform"
        #endif
    }
    
    #if os(iOS) || os(tvOS)
    private func appStateString(_ state: UIApplication.State) -> String {
        switch state {
        case .active:
            return "foreground"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
    #endif
    
    // MARK: - Reset
    
    /// Clear heartbeat state. Called by PaylisherSDK.reset().
    func reset() {
        tokenLock.withLock {
            _fcmToken = nil
        }
        timestampLock.withLock {
            _lastHeartbeatTimestamp = 0
        }
        hedgeLog("[Heartbeat] State reset.")
    }
}
