#if os(iOS)
import UIKit
import ObjectiveC.runtime

public enum ViewLayoutTracker {
    public static var hasChanges = false
    private static var hasSwizzled = false

    public static func viewDidLayout(view _: UIView) {
        hasChanges = true
    }

    public static func clear() {
        hasChanges = false
    }

    public static func swizzleLayoutSubviews() {
        guard !hasSwizzled else { return }

        let originalSelector = #selector(UIView.layoutSubviews)
        let swizzledSelector = #selector(UIView.swizzled_layoutSubviews)

        guard let originalMethod = class_getInstanceMethod(UIView.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
        hasSwizzled = true
        
    }

    public static func unSwizzleLayoutSubviews() {
        guard hasSwizzled else { return }

        let originalSelector = #selector(UIView.layoutSubviews)
        let swizzledSelector = #selector(UIView.swizzled_layoutSubviews)

        guard let originalMethod = class_getInstanceMethod(UIView.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(swizzledMethod, originalMethod)
        hasSwizzled = false
    }
}

extension UIView {
    @objc func swizzled_layoutSubviews() {
        self.swizzled_layoutSubviews()

        if Thread.isMainThread {
            ViewLayoutTracker.viewDidLayout(view: self)
        }
    }
}
#endif

