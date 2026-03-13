//
//  UIViewController.swift
//  Paylisher
//
// Inspired by
// https://raw.githubusercontent.com/segmentio/analytics-swift/e613e09aa1b97144126a923ec408374f914a6f2e/Examples/other_plugins/UIKitScreenTracking.swift
//
//  Created by Manoel Aranda Neto on 23.10.23.
//

#if os(iOS) || os(tvOS)
    import Foundation
    import UIKit

    private enum PaylisherAutoScreenCaptureDeduper {
        static let dedupeWindowSeconds: TimeInterval = 1.0
        static let lock = NSLock()
        static var lastScreenName: String?
        static var lastCapturedAt: Date?
        static var lastControllerIdentifier: ObjectIdentifier?
    }

    extension UIViewController {
        static func swizzleScreenView() {
            swizzle(forClass: UIViewController.self,
                    original: #selector(UIViewController.viewDidAppear(_:)),
                    new: #selector(UIViewController.viewDidApperOverride))
        }

        static func unswizzleScreenView() {
            swizzle(forClass: UIViewController.self,
                    original: #selector(UIViewController.viewDidApperOverride),
                    new: #selector(UIViewController.viewDidAppear(_:)))
        }

        private func activeController() -> UIViewController? {
            // if a view is being dismissed, this will return nil
            if let root = viewIfLoaded?.window?.rootViewController {
                return root
            } else {
                // preferred way to get active controller in ios 13+
                for scene in UIApplication.shared.connectedScenes where scene.activationState == .foregroundActive {
                    let windowScene = scene as? UIWindowScene
                    let sceneDelegate = windowScene?.delegate as? UIWindowSceneDelegate
                    if let target = sceneDelegate, let window = target.window {
                        return window?.rootViewController
                    }
                }
            }
            return nil
        }

        static func getViewControllerName(_ viewController: UIViewController, className overrideClassName: String? = nil) -> String? {
            let className = overrideClassName ?? String(describing: viewController.classForCoder)

            // Check for mapped screen name first.
            if let mappedName = PaylisherScreenMapper.shared.screenName(for: className) {
                return mappedName
            }

            if isSwiftUIHostingController(className) {
                // Prefer explicit titles if available.
                if let title = resolvedTitle(from: viewController) {
                    return mapResolvedScreenNameIfNeeded(title)
                }

                if let inferredName = extractSwiftUIViewName(from: className) {
                    return mapResolvedScreenNameIfNeeded(inferredName)
                }

                hedgeLog("[AutoScreen] Skipping SwiftUI auto screen capture. Could not resolve a meaningful screen name from: \(className)")
                return nil
            }

            var title: String? = className.replacingOccurrences(of: "ViewController", with: "")

            if title?.isEmpty == true {
                title = viewController.title ?? nil
            }

            guard let title else {
                return nil
            }

            return mapResolvedScreenNameIfNeeded(title)
        }

        static func isSwiftUIHostingController(_ className: String) -> Bool {
            className.contains("UIHostingController")
                || className.contains("PresentationHostingController")
        }

        static func extractSwiftUIViewName(from className: String) -> String? {
            guard let payload = extractGenericPayload(from: className) else {
                return nil
            }

            let placeholderTokens: Set<String> = [
                "UIHostingController", "PresentationHostingController",
                "ModifiedContent", "AnyView", "TupleView", "Optional",
                "NavigationView", "NavigationStack", "NavigationSplitView",
                "VStack", "HStack", "ZStack", "ScrollView", "List", "Group",
                "GeometryReader", "Section", "ForEach", "LazyVStack",
                "LazyHStack", "LazyVGrid", "LazyHGrid",
                "RootModifier", "Content", "EmptyView", "SwiftUI",
            ]

            let tokens = payload
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" })
                .map(String.init)
                .filter { token in
                    !token.isEmpty
                        && !token.hasPrefix("_")
                        && !placeholderTokens.contains(token)
                        && !token.hasSuffix("Modifier")
                }

            if let viewLikeToken = tokens.first(where: { $0.hasSuffix("View") || $0.hasSuffix("Screen") }) {
                return viewLikeToken
            }

            if tokens.count == 1 {
                return tokens.first
            }

            return nil
        }

        static func extractGenericPayload(from className: String) -> String? {
            guard let start = className.firstIndex(of: "<") else {
                return nil
            }

            let payloadStart = className.index(after: start)
            var cursor = payloadStart
            var nestedDepth = 0

            while cursor < className.endIndex {
                let character = className[cursor]
                if character == "<" {
                    nestedDepth += 1
                } else if character == ">" {
                    if nestedDepth == 0 {
                        return String(className[payloadStart ..< cursor])
                    }
                    nestedDepth -= 1
                }
                cursor = className.index(after: cursor)
            }

            return nil
        }

        static func shouldCaptureAutoScreenView(_ screenName: String,
                                                from viewController: UIViewController? = nil,
                                                at timestamp: Date = now()) -> Bool
        {
            var shouldCapture = true
            let currentControllerIdentifier = viewController.map { ObjectIdentifier($0) }

            PaylisherAutoScreenCaptureDeduper.lock.withLock {
                if
                    let lastScreenName = PaylisherAutoScreenCaptureDeduper.lastScreenName,
                    let lastCapturedAt = PaylisherAutoScreenCaptureDeduper.lastCapturedAt,
                    let lastControllerIdentifier = PaylisherAutoScreenCaptureDeduper.lastControllerIdentifier,
                    let currentControllerIdentifier = currentControllerIdentifier,
                    lastScreenName == screenName,
                    lastControllerIdentifier == currentControllerIdentifier,
                    timestamp.timeIntervalSince(lastCapturedAt) < PaylisherAutoScreenCaptureDeduper.dedupeWindowSeconds
                {
                    shouldCapture = false
                    return
                }

                if
                    let lastScreenName = PaylisherAutoScreenCaptureDeduper.lastScreenName,
                    lastScreenName == screenName
                {
                    shouldCapture = false
                    return
                }

                PaylisherAutoScreenCaptureDeduper.lastScreenName = screenName
                PaylisherAutoScreenCaptureDeduper.lastCapturedAt = timestamp
                PaylisherAutoScreenCaptureDeduper.lastControllerIdentifier = currentControllerIdentifier
            }

            return shouldCapture
        }

        static func resetAutoScreenCaptureDedupeState() {
            PaylisherAutoScreenCaptureDeduper.lock.withLock {
                PaylisherAutoScreenCaptureDeduper.lastScreenName = nil
                PaylisherAutoScreenCaptureDeduper.lastCapturedAt = nil
                PaylisherAutoScreenCaptureDeduper.lastControllerIdentifier = nil
            }
        }

        private static func resolvedTitle(from viewController: UIViewController) -> String? {
            let title = viewController.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let title, !title.isEmpty {
                return title
            }

            let navigationTitle = viewController.navigationItem.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let navigationTitle, !navigationTitle.isEmpty {
                return navigationTitle
            }

            return nil
        }

        private static func mapResolvedScreenNameIfNeeded(_ name: String) -> String {
            if let mappedName = PaylisherScreenMapper.shared.mappedName(for: name) {
                return mappedName
            }

            return name
        }

        private func captureScreenView(_ window: UIWindow?) {
            let rootController = window?.rootViewController ?? activeController()
            guard let top = findVisibleViewController(rootController) else { return }
            guard let captureCandidate = UIViewController.screenCaptureCandidate(current: self, top: top) else { return }

            let name = UIViewController.getViewControllerName(captureCandidate)

            if let name = name {
                if UIViewController.shouldCaptureAutoScreenView(name, from: captureCandidate) {
                    PaylisherSDK.shared.screen(name)
                } else {
                    hedgeLog("[AutoScreen] Skipping duplicate auto screen event for '\(name)' within \(PaylisherAutoScreenCaptureDeduper.dedupeWindowSeconds)s window.")
                }
            }
        }

        static func screenCaptureCandidate(current: UIViewController, top: UIViewController) -> UIViewController? {
            let currentClassName = String(describing: current.classForCoder)

            // SwiftUI TabView and nested hosting flows may call viewDidAppear on child
            // hosting controllers while `top` still resolves to the app root host.
            // In that case, prefer the appearing hosting controller.
            if isSwiftUIHostingController(currentClassName) {
                return current
            }

            if current === top {
                return top
            }

            return nil
        }

        @objc func viewDidApperOverride(animated: Bool) {
            captureScreenView(viewIfLoaded?.window)
            // it looks like we're calling ourselves, but we're actually
            // calling the original implementation of viewDidAppear since it's been swizzled.
            viewDidApperOverride(animated: animated)
        }

        private func findVisibleViewController(_ controller: UIViewController?) -> UIViewController? {
            if let navigationController = controller as? UINavigationController {
                return findVisibleViewController(navigationController.visibleViewController)
            }
            if let tabController = controller as? UITabBarController {
                if let selected = tabController.selectedViewController {
                    return findVisibleViewController(selected)
                }
            }
            if let presented = controller?.presentedViewController {
                return findVisibleViewController(presented)
            }
            return controller
        }
    }
#endif
