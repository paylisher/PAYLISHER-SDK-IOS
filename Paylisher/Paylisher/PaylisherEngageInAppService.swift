import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#endif

final class PaylisherEngageInAppService {
    static let shared = PaylisherEngageInAppService()

    private init() {}

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
        DispatchQueue.main.async {
            let windowScene = self.activeWindowScene()
            messages.forEach { message in
                self.presentMessage(message, windowScene: windowScene, debugLogging: debugLogging)
            }
        }
        #endif
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
