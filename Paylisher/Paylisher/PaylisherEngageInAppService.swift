import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#endif

@objc public enum InAppAckStatus: Int {
    case delivered, seen, clicked, dismissed
    var rawString: String {
        switch self {
        case .delivered: return "DELIVERED"
        case .seen: return "SEEN"
        case .clicked: return "CLICKED"
        case .dismissed: return "DISMISSED"
        }
    }
}

/// Engage in-app "pull" delivery. Mirrors paylisher-android's in-app flow
/// (PaylisherAndroid.kt + PaylisherEngageInAppApi.kt) 1:1:
///  - foreground fetch (triggered by PaylisherSDK.handleAppDidBecomeActive with a
///    2s delay, mirroring Android ProcessLifecycleOwner.onResume + foregroundFetchDelayMs)
///  - sdkKey derived from the SDK apiKey, fetchEndpoint from the SDK host
///  - shouldDisplayMessage gate (displayTime - 60s buffer / expireDate)
///  - 1-hour de-dup window keyed by pushId (processedNotifications)
///  - delayed rendering: max(condition.delay minutes, displayTime - now)
///  - DELIVERED ack sent at enqueue time
final class PaylisherEngageInAppService: NSObject {
    static let shared = PaylisherEngageInAppService()

    private let queueLock = NSLock()
    private var pendingMessages: [[String: Any]] = []

    // De-dup: key -> first-seen epoch seconds. Mirrors Android processedNotifications
    // (notificationTimeoutMs = 1h). Same pushId is not re-shown within the window.
    private let processedLock = NSLock()
    private var processedNotifications: [String: TimeInterval] = [:]
    private let notificationTimeoutSeconds: TimeInterval = 3600 // Android: 3600000ms (1 hour)

    override private init() {
        super.init()
        #if os(iOS) || os(tvOS)
        // Render queued messages when the app becomes active. The fetch itself is
        // triggered by PaylisherSDK.handleAppDidBecomeActive (2s delay), mirroring
        // Android where ProcessLifecycleOwner.onResume fetches and onActivityResumed
        // renders. We intentionally do NOT fetch here to avoid a duplicate request.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForegroundForRender),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Fetch

    func refresh(using sdk: PaylisherSDK, target: String? = nil) {
        guard let config = sdk.config.engageInAppConfig else {
            return
        }

        let distinctId = sdk.getDistinctId().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !distinctId.isEmpty else {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app fetch skipped: distinctId is empty")
            }
            return
        }

        let endpoint = resolveFetchURLString(config: config, sdk: sdk)
        guard let url = URL(string: endpoint) else {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app fetch skipped: invalid fetchEndpoint \(endpoint)")
            }
            return
        }

        let effectiveSdkKey = resolveSdkKey(config: config, sdk: sdk)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(effectiveSdkKey, forHTTPHeaderField: "X-SDK-Key")

        // Android passes `target` straight through (null on foreground fetch). We do
        // NOT fall back to the current screen, so server-side target matching behaves
        // identically across platforms.
        let body = buildRequestBody(
            config: config,
            sdkKey: effectiveSdkKey,
            distinctId: distinctId,
            target: target
        )

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app fetch body encode failed: \(error)")
            }
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                if config.debugLogging {
                    hedgeLog("[PaylisherSDK] Engage in-app fetch failed: \(error.localizedDescription)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                if config.debugLogging {
                    hedgeLog("[PaylisherSDK] Engage in-app fetch failed with status \(httpResponse.statusCode)")
                }
                return
            }

            guard let data, !data.isEmpty else {
                return
            }

            self.handleResponseData(data, debugLogging: config.debugLogging)
        }.resume()
    }

    // MARK: - Ack

    func acknowledge(distinctId: String, pushId: String, status: InAppAckStatus) {
        #if os(iOS) || os(tvOS)
        guard let config = PaylisherSDK.shared.config.engageInAppConfig else {
            return
        }

        // Android acks only when pushId is numeric (toIntOrNull); match that, and
        // send pushId as an integer (the Engage ack DTO expects a number).
        guard let pushIdInt = Int(pushId) else {
            return
        }

        let endpoint = resolveFetchURLString(config: config, sdk: PaylisherSDK.shared)
        let ackEndpoint = ackUrlString(from: endpoint)
        guard let url = URL(string: ackEndpoint) else {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app ack skipped: invalid ack endpoint \(ackEndpoint)")
            }
            return
        }

        let effectiveSdkKey = resolveSdkKey(config: config, sdk: PaylisherSDK.shared)

        var body: [String: Any] = [
            "sdkKey": effectiveSdkKey,
            "distinctId": distinctId,
            "pushId": pushIdInt,
            "status": status.rawString,
        ]
        if let teamId = config.teamId, !teamId.isEmpty { body["teamId"] = teamId }
        if let projectId = config.projectId, !projectId.isEmpty { body["projectId"] = projectId }
        if let sourceId = config.sourceId, !sourceId.isEmpty { body["sourceId"] = sourceId }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(effectiveSdkKey, forHTTPHeaderField: "X-SDK-Key")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app ack body encode failed: \(error)")
            }
            return
        }

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error, config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app ack failed: \(error.localizedDescription)")
            }
        }.resume()
        #endif
    }

    // MARK: - URL / key resolution (mirrors Android resolveFetchUrl / effectiveSdkKey)

    private func resolveFetchURLString(config: PaylisherEngageInAppConfig, sdk: PaylisherSDK) -> String {
        if let endpoint = config.fetchEndpoint, !endpoint.isEmpty {
            return endpoint
        }
        let host = sdk.config.host.absoluteString
        let trimmed = host.hasSuffix("/") ? String(host.dropLast()) : host
        return "\(trimmed)/v1/push/inapp/fetch"
    }

    private func resolveSdkKey(config: PaylisherEngageInAppConfig, sdk: PaylisherSDK) -> String {
        if let key = config.sdkKey, !key.isEmpty {
            return key
        }
        return sdk.config.apiKey
    }

    private func ackUrlString(from fetchEndpoint: String) -> String {
        guard let lastSlash = fetchEndpoint.lastIndex(of: "/") else {
            return fetchEndpoint
        }
        let prefix = fetchEndpoint[..<fetchEndpoint.index(after: lastSlash)]
        return prefix + "ack"
    }

    private func buildRequestBody(
        config: PaylisherEngageInAppConfig,
        sdkKey: String,
        distinctId: String,
        target: String?
    ) -> [String: Any] {
        var body: [String: Any] = [
            "distinctId": distinctId,
            "sdkKey": sdkKey,
            "platform": "ios",
            "maxMessages": max(1, min(config.maxMessages, 5)),
        ]

        if let teamId = config.teamId, !teamId.isEmpty { body["teamId"] = teamId }
        if let projectId = config.projectId, !projectId.isEmpty { body["projectId"] = projectId }
        if let sourceId = config.sourceId, !sourceId.isEmpty { body["sourceId"] = sourceId }
        if let target, !target.isEmpty { body["target"] = target }

        return body
    }

    // MARK: - Response handling / de-dup / display gate

    private func handleResponseData(_ data: Data, debugLogging: Bool) {
        guard
            let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let messages = jsonObject["messages"] as? [[String: Any]],
            !messages.isEmpty
        else {
            return
        }

        #if os(iOS) || os(tvOS)
        queueLock.lock()
        for message in messages {
            // Android applies shouldDisplayMessage + shouldProcessNotification in the
            // fetch callback, before queueing.
            if !shouldDisplayMessage(message) {
                continue
            }
            let key = buildInAppNotificationKey(message)
            if !shouldProcessNotification(key) {
                if debugLogging {
                    hedgeLog("[PaylisherSDK] Skipping duplicate Engage in-app message: \(key)")
                }
                continue
            }
            pendingMessages.append(message)
        }
        queueLock.unlock()

        renderPendingMessages(debugLogging: debugLogging)
        #endif
    }

    /// Mirrors Android shouldProcessNotification: 1-hour window, key recorded on first sight.
    private func shouldProcessNotification(_ key: String) -> Bool {
        processedLock.lock()
        defer { processedLock.unlock() }

        let nowSeconds = Date().timeIntervalSince1970
        processedNotifications = processedNotifications.filter { _, timestamp in
            timestamp + notificationTimeoutSeconds >= nowSeconds
        }

        if processedNotifications[key] != nil {
            return false
        }
        processedNotifications[key] = nowSeconds
        return true
    }

    /// Mirrors Android buildInAppNotificationKey: pushId (if present) else "inapp-<ms>".
    /// displayTime is intentionally NOT part of the key (server regenerates it per fetch).
    private func buildInAppNotificationKey(_ message: [String: Any]) -> String {
        if let pushId = extractPushId(from: message), !pushId.isEmpty {
            return pushId
        }
        return "inapp-\(Int(Date().timeIntervalSince1970 * 1000))"
    }

    /// Mirrors Android shouldDisplayMessage: displayTime (60s buffer) / expireDate gate.
    private func shouldDisplayMessage(_ message: [String: Any]) -> Bool {
        let condition = conditionDict(from: message)
        let nowMs = Date().timeIntervalSince1970 * 1000

        if let displayTime = longValue(condition?["displayTime"]) {
            if nowMs < Double(displayTime) - 60_000 {
                return false
            }
        }
        if let expireDate = longValue(condition?["expireDate"]) {
            if nowMs > Double(expireDate) {
                return false
            }
        }
        return true
    }

    /// Mirrors Android showInAppNotification initialDelay:
    /// max(condition.delay minutes, displayTime - now). Returned in seconds.
    private func initialDelaySeconds(for message: [String: Any]) -> TimeInterval {
        let condition = conditionDict(from: message)
        let nowMs = Date().timeIntervalSince1970 * 1000

        let delayMinutes = intValue(condition?["delay"]) ?? 0
        let conditionDelayMs = Double(delayMinutes) * 60_000

        var displayDelayMs: Double = 0
        if let displayTime = longValue(condition?["displayTime"]) {
            displayDelayMs = max(0, Double(displayTime) - nowMs)
        }

        return max(conditionDelayMs, displayDelayMs) / 1000.0
    }

    private func conditionDict(from message: [String: Any]) -> [String: Any]? {
        return (message["payload"] as? [String: Any])?["condition"] as? [String: Any]
    }

    private func longValue(_ value: Any?) -> Int64? {
        switch value {
        case let number as NSNumber: return number.int64Value
        case let string as String: return Int64(string)
        default: return nil
        }
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: return number.intValue
        case let string as String: return Int(string)
        default: return nil
        }
    }

    private func extractPushId(from message: [String: Any]) -> String? {
        let raw = (message["payload"] as? [String: Any])?["pushId"] ?? message["pushId"]
        switch raw {
        case let value as String: return value
        case let value as NSNumber: return String(describing: value)
        default: return nil
        }
    }

    private func isExcludedScreen(currentTarget: String?, config: PaylisherEngageInAppConfig) -> Bool {
        guard let currentTarget, !currentTarget.isEmpty else {
            return false
        }
        for name in config.excludedActivities {
            if currentTarget.range(of: name, options: .caseInsensitive) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Render

    @objc private func handleAppForegroundForRender() {
        let debugLogging = PaylisherSDK.shared.config.engageInAppConfig?.debugLogging ?? false
        renderPendingMessages(debugLogging: debugLogging)
    }

    /// Render hook for screen transitions. Mirrors Android onActivityResumed ->
    /// renderPendingInAppMessages so a message queued on an excluded screen (e.g.
    /// Splash) renders as soon as a non-excluded screen appears.
    func onScreenAppeared() {
        let debugLogging = PaylisherSDK.shared.config.engageInAppConfig?.debugLogging ?? false
        renderPendingMessages(debugLogging: debugLogging)
    }

    private func renderPendingMessages(debugLogging: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            #if os(iOS) || os(tvOS)
            guard let config = PaylisherSDK.shared.config.engageInAppConfig else {
                return
            }

            guard let scene = self.activeWindowScene() else {
                return
            }

            let target = self.currentScreenTarget()
            if self.isExcludedScreen(currentTarget: target, config: config) {
                return
            }

            self.queueLock.lock()
            let drained = self.pendingMessages
            self.pendingMessages.removeAll()
            self.queueLock.unlock()

            if drained.isEmpty {
                return
            }

            let distinctId = PaylisherSDK.shared.getDistinctId()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for message in drained {
                // Android acks DELIVERED right after enqueue (before the delayed
                // render fires), so we ack here too. acknowledge() no-ops for a
                // non-numeric pushId, mirroring Android's toIntOrNull guard.
                if let pushId = self.extractPushId(from: message), !distinctId.isEmpty {
                    self.acknowledge(distinctId: distinctId, pushId: pushId, status: .delivered)
                }

                let delay = self.initialDelaySeconds(for: message)
                if delay <= 0 {
                    self.presentMessage(message, windowScene: scene, debugLogging: debugLogging)
                } else {
                    // Mirrors Android InAppTaskWorker.setInitialDelay: present after the
                    // delay using whatever scene is foreground at fire time.
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self else { return }
                        guard let laterScene = self.activeWindowScene() else { return }
                        self.presentMessage(message, windowScene: laterScene, debugLogging: debugLogging)
                    }
                }
            }
            #endif
        }
    }

    #if os(iOS) || os(tvOS)
    private func activeWindowScene() -> UIWindowScene? {
        return UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
    }

    private func currentScreenTarget() -> String? {
        guard
            let rootViewController = activeWindowScene()?
                .windows
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        else {
            return nil
        }

        return topViewController(from: rootViewController)
            .map { String(describing: type(of: $0)) }
    }

    private func topViewController(from viewController: UIViewController) -> UIViewController? {
        if let presented = viewController.presentedViewController {
            return topViewController(from: presented)
        }

        if let navigation = viewController as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }

        if let tabBar = viewController as? UITabBarController,
           let selected = tabBar.selectedViewController {
            return topViewController(from: selected)
        }

        return viewController
    }

    private func presentMessage(
        _ message: [String: Any],
        windowScene: UIWindowScene?,
        debugLogging: Bool
    ) {
        guard let payload = message["payload"] as? [String: Any] else {
            return
        }

        let layoutType = (payload["layoutType"] as? String) ?? "native"

        if layoutType == "native" {
            var userInfo = payload
            userInfo["type"] = "IN-APP"

            if let nativePayload = payload["native"] {
                userInfo["native"] = jsonString(from: nativePayload) ?? ""
            }

            if let conditionPayload = payload["condition"] {
                userInfo["condition"] = jsonString(from: conditionPayload) ?? ""
            }

            PaylisherNativeInAppNotificationManager.shared.nativeInAppNotification(
                userInfo: userInfo,
                windowScene: windowScene
            )
            return
        }

        do {
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            let decodedPayload = try JSONDecoder().decode(CustomInAppPayload.self, from: payloadData)
            PaylisherCustomInAppNotificationManager.shared.showCustomInApp(
                decodedPayload,
                windowScene: windowScene
            )
        } catch {
            if debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app payload decode failed: \(error)")
            }
        }
    }
    #endif

    private func jsonString(from value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value) else {
            return nil
        }

        guard let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
