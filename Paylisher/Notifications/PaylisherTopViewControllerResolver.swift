//
//  PaylisherTopViewControllerResolver.swift
//  Paylisher
//
//  In-app mesajlar kök view controller'dan present ediliyordu. Kullanıcı uygulama
//  içinde gezinirken (sheet, fullScreenCover, alert veya başka bir modal açıkken)
//  UIKit "presenting a view controller which is already presenting" durumunda
//  sessizce hiçbir şey yapmıyor; modal görünmüyor ve inappMessageRead atılmıyordu.
//  Bu yardımcı, gösterim anında en üstteki view controller'ı çözer.
//

#if os(iOS)
import UIKit

enum PaylisherTopViewControllerResolver {
    static func topViewController(from viewController: UIViewController) -> UIViewController? {
        if let presented = viewController.presentedViewController,
           !presented.isBeingDismissed {
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
}
#endif
