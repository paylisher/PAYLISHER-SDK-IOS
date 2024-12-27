//
//  PaylisherMaskViewModifier.swift
//  Paylisher
//
//  Created by Yiannis Josephides on 09/10/2024.
//

#if os(iOS) && canImport(SwiftUI)

    import SwiftUI

    public extension View {
        func paylisherMask(_ isEnabled: Bool = true) -> some View {
            modifier(PaylisherMaskViewModifier(enabled: isEnabled))
        }
    }

    private struct PaylisherMaskViewTagger: UIViewRepresentable {
        func makeUIView(context _: Context) -> PaylisherMaskViewTaggerView {
            PaylisherMaskViewTaggerView()
        }

        func updateUIView(_: PaylisherMaskViewTaggerView, context _: Context) {
            // nothing
        }
    }

    private struct PaylisherMaskViewModifier: ViewModifier {
        let enabled: Bool

        func body(content: Content) -> some View {
            content.background(viewTagger)
        }

        @ViewBuilder
        private var viewTagger: some View {
            if enabled {
                PaylisherMaskViewTagger()
            }
        }
    }

    private class PaylisherMaskViewTaggerView: UIView {
        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            superview?.phIsManuallyMasked = true
        }
    }

    private var phIsManuallyMaskedKey: UInt8 = 0
    extension UIView {
        var phIsManuallyMasked: Bool {
            get {
                objc_getAssociatedObject(self, &phIsManuallyMaskedKey) as? Bool ?? false
            }

            set {
                objc_setAssociatedObject(
                    self,
                    &phIsManuallyMaskedKey,
                    newValue as Bool?,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
    }
#endif
