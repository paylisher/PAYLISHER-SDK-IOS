import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#endif

@objc public enum InAppAckStatus: Int {
    case delivered, seen, clicked, dismissed
    var rawString: String {
        switch self {
        case .delivered: return "DELIVERED"
        case .seen:      return "SEEN"
        case .clicked:   return "CLICKED"
        case .dismissed: return "DISMISSED"
        }
    }
}

final class PaylisherEngageInAppService: NSObject {
    static let shared = PaylisherEngageInAppService()

    private let queueLock = NSLock()
    private var pendingMessages: [[String: Any]] = []
    private var presentedPushIds = Set<String>()

    override private init() {
        super.init()
        #if os(iOS) || os(tvOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForegroundForRender),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        // Foreground auto-fetch parity with paylisher-android (ProcessLifecycleOwner +
        // autoFetchOnForeground=true). Without this, iOS users never see in-app messages
        // unless the host app calls refresh() manually.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForegroundForFetch),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

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

        guard let url = URL(string: config.fetchEndpoint) else {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app fetch skipped: invalid fetchEndpoint \(config.fetchEndpoint)")
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.sdkKey, forHTTPHeaderField: "X-SDK-Key")

        let resolvedTarget = target ?? currentScreenTarget()
        let body = buildRequestBody(
            config: config,
            distinctId: distinctId,
            target: resolvedTarget
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

    func acknowledge(distinctId: String, pushId: String, status: InAppAckStatus) {
        #if os(iOS) || os(tvOS)
        guard let config = PaylisherSDK.shared.config.engageInAppConfig else {
            return
        }

        let ackEndpoint = ackUrlString(from: config.fetchEndpoint)
        guard let url = URL(string: ackEndpoint) else {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app ack skipped: invalid ack endpoint \(ackEndpoint)")
            }
            return
        }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""

        let body: [String: Any] = [
            "teamId": config.teamId,
            "projectId": config.projectId,
            "sourceId": config.sourceId,
            "sdkKey": config.sdkKey,
            "distinctId": distinctId,
            "deviceId": deviceId,
            "pushId": pushId,
            "status": status.rawString,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.sdkKey, forHTTPHeaderField: "X-SDK-Key")

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

    private func ackUrlString(from fetchEndpoint: String) -> String {
        guard let lastSlash = fetchEndpoint.lastIndex(of: "/") else {
            return fetchEndpoint
        }
        let prefix = fetchEndpoint[..<fetchEndpoint.index(after: lastSlash)]
        return prefix + "ack"
    }

    private func buildRequestBody(
        config: PaylisherEngageInAppConfig,
        distinctId: String,
        target: String?
    ) -> [String: Any] {
        var body: [String: Any] = [
            "teamId": config.teamId,
            "projectId": config.projectId,
            "sourceId": config.sourceId,
            "distinctId": distinctId,
            "sdkKey": config.sdkKey,
            "platform": "ios",
            "maxMessages": max(1, min(config.maxMessages, 5)),
        ]

        if let target, !target.isEmpty {
            body["target"] = target
        }

        return body
    }

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
            if let pushId = extractPushId(from: message) {
                if presentedPushIds.contains(pushId) { continue }
                presentedPushIds.insert(pushId)
            }
            pendingMessages.append(message)
        }
        queueLock.unlock()

        renderPendingMessages(debugLogging: debugLogging)
        #endif
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

    @objc private func handleAppForegroundForRender() {
        let debugLogging = PaylisherSDK.shared.config.engageInAppConfig?.debugLogging ?? false
        renderPendingMessages(debugLogging: debugLogging)
    }

    @objc private func handleAppWillEnterForegroundForFetch() {
        guard let config = PaylisherSDK.shared.config.engageInAppConfig, config.autoFetchOnForeground else {
            return
        }
        #if os(iOS) || os(tvOS)
        // Skip auto-fetch on excluded screens (e.g. Splash). The fetched messages would
        // queue up anyway, but avoiding the HTTP call mirrors Android's excludedActivities.
        if isExcludedScreen(currentTarget: currentScreenTarget(), config: config) {
            return
        }
        #endif
        refresh(using: PaylisherSDK.shared)
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
                self.presentMessage(message, windowScene: scene, debugLogging: debugLogging)

                if let pushId = self.extractPushId(from: message), !distinctId.isEmpty {
                    self.acknowledge(distinctId: distinctId, pushId: pushId, status: .delivered)
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
