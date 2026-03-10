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

        static func getViewControllerName(_ viewController: UIViewController) -> String? {
            let className = String(describing: viewController.classForCoder)
            
            // Check for mapped screen name first
            if let mappedName = PaylisherScreenMapper.shared.screenName(for: className) {
                return mappedName
            }
            
            // Handle SwiftUI's hosting controllers
            let isSwiftUI = className.hasPrefix("UIHostingController") || className.hasPrefix("PresentationHostingController")
            if isSwiftUI {
                // 1. Try to get the title set via .navigationTitle() or UIViewController.title
                if let viewTitle = viewController.title, !viewTitle.isEmpty {
                    return viewTitle
                }
                if let navTitle = viewController.navigationItem.title, !navTitle.isEmpty {
                    return navTitle
                }
                
                // 2. Extract the innermost custom SwiftUI View name
                if let cleanedName = extractSwiftUIViewName(from: className) {
                    return cleanedName
                }
                
                // If it's pure AnyView or unparseable, don't send a messy event
                return nil
            }
            
            var title: String? = className.replacingOccurrences(of: "ViewController", with: "")

            if title?.isEmpty == true {
                title = viewController.title ?? nil
            }

            return title
        }

        static func extractSwiftUIViewName(from className: String) -> String? {
            var name = className
            if let range = name.range(of: "<") {
                name = String(name[range.upperBound...])
            }
            if name.hasSuffix(">") {
                name = String(name.dropLast())
            }
            
            // Apple wrappers and modifiers we want to ignore
            let appleWrappers: Set<String> = [
                "ModifiedContent", "AnyView", "TupleView", "Optional",
                "NavigationView", "VStack", "HStack", "ZStack",
                "ScrollView", "List", "Group", "GeometryReader"
            ]
            
            let components = name.components(separatedBy: CharacterSet.alphanumerics.inverted)
            for component in components {
                // Find the first meaningful custom struct name
                if !component.isEmpty && !appleWrappers.contains(component) && !component.hasSuffix("Modifier") {
                    return component.replacingOccurrences(of: "View", with: "")
                }
            }
            return nil
        }

        private func captureScreenView(_ window: UIWindow?) {
            var rootController = window?.rootViewController
            if rootController == nil {
                rootController = activeController()
            }
            guard let top = findVisibleViewController(activeController()) else { return }

            let name = UIViewController.getViewControllerName(top)

            if let name = name {
                PaylisherSDK.shared.screen(name)
            }
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
