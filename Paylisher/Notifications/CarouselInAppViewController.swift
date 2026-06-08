//
//  CarouselInAppViewController.swift
//  Paylisher
//

import UIKit

class CarouselInAppViewController: UIViewController, UIScrollViewDelegate {

    // MARK: - Properties

    // Modal geometry — kept in sync with StyleViewController + Studio +
    // Android. The carousel's modal mode now uses the SAME ratio-driven
    // contract as the single modal so authored percent fields (margins,
    // fontSize, gap, radius) resolve identically across the two paths.
    private let modalHeightRatio: CGFloat = 0.48
    private let modalWidthRatio: CGFloat = 0.88
    private let modalInnerHorizontalPaddingRatio: CGFloat = 0.05
    private let modalInnerVerticalPaddingRatio: CGFloat = 0.05
    private let modalImageHeightRatio: CGFloat = 0.36
    private let modalImageMinHeight: CGFloat = 72

    // Fullscreen geometry — mirrors StyleViewController's fullscreen
    // contract. Container fills the device; inner padding is 4% of width/
    // height; min top/bottom insets layered on top of the device safeArea
    // so notch-less phones still get breathing room.
    private let fullscreenInnerHorizontalPaddingRatio: CGFloat = 0.04
    private let fullscreenInnerVerticalPaddingRatio: CGFloat = 0.04
    private let fullscreenImageHeightRatio: CGFloat = 0.32
    private let fullscreenMinTopInset: CGFloat = 60
    private let fullscreenMinBottomInset: CGFloat = 35

    // iPhone-13 reference container dimensions — authored pt values (image
    // intrinsic 60pt, button heights 32/44/56pt, padding 4pt etc.) scale
    // from these to the current device's container so visual proportions
    // stay identical. Same constants StyleViewController uses.
    private var modalReferenceWidth: CGFloat { 390 * modalWidthRatio }   // 343.2
    private var modalReferenceHeight: CGFloat { 844 * modalHeightRatio } // 405.12
    private let fullscreenReferenceWidth: CGFloat = 390
    private let fullscreenReferenceHeight: CGFloat = 844

    private let baseHorizontalInset: CGFloat = 16
    private let extraHorizontalInset: CGFloat = 6

    private let layouts: [CustomInAppPayload.Layout]
    private let defaultLang: String
    private let isFullscreen: Bool
    private let pushId: String?

    private var currentIndex: Int = 0
    private var hasAppliedInitialTransition = false

    private var closePositionConstraints: [NSLayoutConstraint] = []
    private var bottomBarHeightConstraint: NSLayoutConstraint?

    private var contentHorizontalInset: CGFloat {
        // Carousel always renders inside the container's ratio-based inner
        // horizontal padding (applied at the page-scrollView level for
        // fullscreen, at the content-scrollView level for modal). Per-block
        // wrappers must NOT add their own legacy inset on top — otherwise
        // a `full`-width button or button-row loses width to double padding.
        // Matches StyleViewController.contentHorizontalInset for modal /
        // fullscreen layoutType (returns 0).
        return 0
    }

    // MARK: - Container content scaling
    //
    // Mirrors StyleViewController so authored payload fields behave
    // IDENTICALLY whether the layout renders via the single-message path
    // or as a carousel slide. Banner is intentionally absent here —
    // carousel only supports modal + fullscreen.

    private var layoutType: String {
        return isFullscreen ? "fullscreen" : "modal"
    }

    /// Carousel uses percent-based authoring for both modal and fullscreen.
    private var isPercentContainer: Bool { true }

    private func currentContainerWidth() -> CGFloat {
        if isFullscreen { return UIScreen.main.bounds.width }
        return UIScreen.main.bounds.width * modalWidthRatio
    }

    private func currentContainerHeight() -> CGFloat {
        if isFullscreen { return UIScreen.main.bounds.height }
        return UIScreen.main.bounds.height * modalHeightRatio
    }

    private func referenceContainerWidth() -> CGFloat {
        return isFullscreen ? fullscreenReferenceWidth : modalReferenceWidth
    }

    private func referenceContainerHeight() -> CGFloat {
        return isFullscreen ? fullscreenReferenceHeight : modalReferenceHeight
    }

    /// Scale a horizontal authored pt value to the current container's
    /// coordinate space. Kept for categorical intrinsics (e.g. image 60pt
    /// banner reference — unused in carousel but kept for API parity).
    private func scaleH(_ pt: CGFloat) -> CGFloat {
        let scale = currentContainerWidth() / referenceContainerWidth()
        return pt * scale
    }

    /// Scale a vertical authored pt value (button heights 32/44/56,
    /// per-block vertical paddings) to the current container's height.
    private func scaleV(_ pt: CGFloat) -> CGFloat {
        let scale = currentContainerHeight() / referenceContainerHeight()
        return pt * scale
    }

    // MARK: - Container percent helpers
    //
    // Authored payload fields (margins, fontSize, radius, gap, verticalSpacing)
    // are PERCENTS of the current container's dimensions (0–100). Carousel
    // resolves them against the current page's container so a slide in a
    // carousel looks identical to the same payload rendered as a single
    // modal / fullscreen. Mirrors StyleViewController's bannerPctH/V.

    private func clampPct(_ value: CGFloat) -> CGFloat {
        return max(0, min(100, value))
    }

    private func bannerPctH(_ raw: CGFloat) -> CGFloat {
        return currentContainerWidth() * clampPct(raw) / 100
    }

    private func bannerPctV(_ raw: CGFloat) -> CGFloat {
        return currentContainerHeight() * clampPct(raw) / 100
    }

    /// Resolve an authored fontSize string (`"16"` / `"16px"`) as % of
    /// container height. Returns the same shape `makeFont` consumes.
    private func scaledFontSizeString(_ raw: String?) -> String? {
        guard let raw = raw else { return nil }
        let trimmed = raw.replacingOccurrences(of: "px", with: "")
        guard let value = Double(trimmed) else { return raw }
        let resolved = bannerPctV(CGFloat(value))
        return String(format: "%g", Double(resolved))
    }

    /// Resolve a button's authored fontSize as % of the button's OWN
    /// height (not container height). Kept for future use — `createStyledButton`
    /// currently uses `scaledFontSizeString` for parity with StyleViewController.
    private func resolveButtonFontSizeString(_ raw: String?, buttonHeight: CGFloat) -> String? {
        guard let raw = raw else { return nil }
        let trimmed = raw.replacingOccurrences(of: "px", with: "")
        guard let value = Double(trimmed) else { return raw }
        let pct = clampPct(CGFloat(value))
        let resolved = buttonHeight * pct / 100
        return String(format: "%g", Double(resolved))
    }

    private var currentLayout: CustomInAppPayload.Layout? {
        guard layouts.indices.contains(currentIndex) else { return layouts.first }
        return layouts[currentIndex]
    }

    private var fullscreenBottomChromeHeight: CGFloat {
        isFullscreen && layouts.count > 1 ? 56 : 0
    }

    // MARK: - UI

    private let overlayView    = UIView()
    private let containerView  = UIView()
    private let pageScrollView = UIScrollView()
    private let pageControl    = UIPageControl()
    private let closeButton    = UIButton(type: .system)
    private let prevArrow      = UIButton(type: .system)
    private let nextArrow      = UIButton(type: .system)
    private let bottomBar      = UIView()

    // MARK: - Init

    init(
        layouts: [CustomInAppPayload.Layout],
        defaultLang: String,
        isFullscreen: Bool = false,
        pushId: String? = nil
    ) {
        self.layouts      = layouts
        self.defaultLang  = defaultLang
        self.isFullscreen = isFullscreen
        self.pushId = pushId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Render-start + geometry log — mirrors Android's
        //   "Modal carousel sizing — modal=<W>x<H> innerPad=… slides=…"
        //   "Fullscreen carousel sizing — viewport=<W>x<H> innerPad=… minSafe=… slides=…"
        let screen = UIScreen.main.bounds
        let kind = isFullscreen ? "Fullscreen" : "Modal"
        let containerW = currentContainerWidth()
        let containerH = currentContainerHeight()
        let innerH = containerW * (isFullscreen
            ? fullscreenInnerHorizontalPaddingRatio
            : modalInnerHorizontalPaddingRatio)
        let innerV = containerH * (isFullscreen
            ? fullscreenInnerVerticalPaddingRatio
            : modalInnerVerticalPaddingRatio)
        print("FCM | InApp | \(kind) Carousel render started — lang=\(defaultLang) pushId=\(pushId ?? "?") slides=\(layouts.count)")
        if isFullscreen {
            print("FCM | InApp | Fullscreen Carousel sizing — viewport=\(Int(screen.width))x\(Int(screen.height)) innerPad=\(Int(innerH))x\(Int(innerV)) minSafe=\(Int(fullscreenMinTopInset))/\(Int(fullscreenMinBottomInset)) bottomChrome=\(Int(fullscreenBottomChromeHeight)) slides=\(layouts.count)")
        } else {
            print("FCM | InApp | Modal Carousel sizing — modal=\(Int(containerW))x\(Int(containerH)) innerPad=\(Int(innerH))x\(Int(innerV)) slides=\(layouts.count)")
        }

        setupUI()

        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        prevArrow.addTarget(self, action: #selector(didTapPrev), for: .touchUpInside)
        nextArrow.addTarget(self, action: #selector(didTapNext), for: .touchUpInside)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasAppliedInitialTransition else { return }
        hasAppliedInitialTransition = true
        applyTransition()

        // Render-complete log — mirrors Android's
        //   "In-App Modal Carousel sent! <locale>"
        //   "In-App Fullscreen Carousel sent! <locale>"
        let kindSent = isFullscreen ? "Fullscreen Carousel" : "Modal Carousel"
        print("FCM | InApp | In-App \(kindSent) sent! locale=\(Locale.current.identifier) pushId=\(pushId ?? "?")")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let expectedOffsetX = pageScrollView.bounds.width * CGFloat(currentIndex)
        if abs(pageScrollView.contentOffset.x - expectedOffsetX) > 1 {
            pageScrollView.contentOffset = CGPoint(x: expectedOffsetX, y: 0)
        }
    }

    // MARK: - Setup

    private func setupUI() {
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        pageScrollView.isPagingEnabled = true
        pageScrollView.showsHorizontalScrollIndicator = false
        pageScrollView.showsVerticalScrollIndicator = false
        pageScrollView.bounces = false
        pageScrollView.delegate = self
        pageScrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pageScrollView)

        let pagesStack = UIStackView()
        pagesStack.axis = .horizontal
        pagesStack.spacing = 0
        pagesStack.distribution = .fillEqually
        pagesStack.translatesAutoresizingMaskIntoConstraints = false
        pageScrollView.addSubview(pagesStack)

        NSLayoutConstraint.activate([
            pagesStack.topAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.topAnchor),
            pagesStack.leadingAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.leadingAnchor),
            pagesStack.trailingAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.trailingAnchor),
            pagesStack.bottomAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.bottomAnchor),
            pagesStack.heightAnchor.constraint(equalTo: pageScrollView.frameLayoutGuide.heightAnchor),
        ])

        for layout in layouts {
            let page = buildPageView(layout)
            page.translatesAutoresizingMaskIntoConstraints = false
            pagesStack.addArrangedSubview(page)
            page.widthAnchor.constraint(equalTo: pageScrollView.frameLayoutGuide.widthAnchor).isActive = true
        }

        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.backgroundColor = .clear
        view.addSubview(bottomBar)

        prevArrow.translatesAutoresizingMaskIntoConstraints = false
        nextArrow.translatesAutoresizingMaskIntoConstraints = false
        prevArrow.setImage(UIImage(systemName: "chevron.left.circle.fill"), for: .normal)
        nextArrow.setImage(UIImage(systemName: "chevron.right.circle.fill"), for: .normal)
        prevArrow.tintColor = .systemGray
        nextArrow.tintColor = .systemGray
        bottomBar.addSubview(prevArrow)
        bottomBar.addSubview(nextArrow)

        pageControl.numberOfPages = layouts.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.35)
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(pageControl)

        NSLayoutConstraint.activate([
            prevArrow.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            prevArrow.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            prevArrow.widthAnchor.constraint(equalToConstant: 32),
            prevArrow.heightAnchor.constraint(equalToConstant: 32),

            nextArrow.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            nextArrow.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            nextArrow.widthAnchor.constraint(equalToConstant: 32),
            nextArrow.heightAnchor.constraint(equalToConstant: 32),

            pageControl.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            pageControl.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
        ])

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isHidden = true
        closeButton.layer.zPosition = 1000
        closeButton.contentHorizontalAlignment = .center
        closeButton.contentVerticalAlignment = .center
        closeButton.imageView?.contentMode = .scaleAspectFit
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])

        if isFullscreen {
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: view.topAnchor),
                containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

                pageScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                pageScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                pageScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                pageScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

                bottomBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                bottomBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                bottomBar.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
                containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                containerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: modalHeightRatio),

                pageScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                pageScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                pageScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                pageScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

                bottomBar.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 8),
                bottomBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                bottomBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
        }

        bottomBarHeightConstraint = bottomBar.heightAnchor.constraint(equalToConstant: layouts.count > 1 ? 48 : 0)
        bottomBarHeightConstraint?.isActive = true

        applyContainerStyleFromFirstLayout()
        updateSlideChrome()
    }

    // MARK: - Style / Close / Overlay

    private func applyContainerStyleFromFirstLayout() {
        guard let style = layouts.first?.style else { return }

        if let bgColorHex = style.bgColor {
            containerView.backgroundColor = UIColor(hex: bgColorHex)
        }

        if isFullscreen {
            containerView.layer.cornerRadius = 0
        } else {
            containerView.layer.cornerRadius = 8
        }

        containerView.clipsToBounds = true
    }

    private func updateSlideChrome() {
        pageControl.currentPage = currentIndex
        pageControl.isHidden = layouts.count <= 1

        if layouts.count <= 1 {
            bottomBarHeightConstraint?.constant = 0
            bottomBar.isHidden = true
        } else {
            bottomBarHeightConstraint?.constant = 48
            bottomBar.isHidden = false
        }

        applyOverlayForCurrentLayout()
        applyCloseForCurrentLayout()
        applySlideFallbackColor()
        updateArrows()
    }

    private func applySlideFallbackColor() {
        guard let style = currentLayout?.style,
              let bgColorHex = style.bgColor,
              let color = UIColor(hex: bgColorHex) else {
            return
        }
        containerView.backgroundColor = color
    }

    private func applyCloseForCurrentLayout() {
        closePositionConstraints.forEach { $0.isActive = false }
        closePositionConstraints.removeAll()

        guard let close = currentLayout?.close else {
            closeButton.isHidden = true
            return
        }

        closeButton.isHidden = !(close.active ?? true)

        let needsSafeTop = isFullscreen
        let safeTopAnchor: NSLayoutYAxisAnchor = needsSafeTop
            ? view.safeAreaLayoutGuide.topAnchor
            : containerView.topAnchor

        // Parity with StyleViewController.applyClose: every position works
        // for both modal and fullscreen carousels. Previous code remapped
        // outside-left / outside-right to inside for modal-carousel; that
        // silently dropped the user's authored placement.
        let position = close.position ?? "right"

        switch position {
        case "left":
            closePositionConstraints = [
                closeButton.topAnchor.constraint(equalTo: safeTopAnchor, constant: 8),
                closeButton.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 8),
            ]

        case "outside-left":
            closePositionConstraints = [
                closeButton.topAnchor.constraint(
                    equalTo: needsSafeTop ? view.safeAreaLayoutGuide.topAnchor : containerView.topAnchor,
                    constant: needsSafeTop ? 8 : -28
                ),
                closeButton.rightAnchor.constraint(equalTo: containerView.leftAnchor, constant: 12),
            ]

        case "outside-right":
            closePositionConstraints = [
                closeButton.topAnchor.constraint(
                    equalTo: needsSafeTop ? view.safeAreaLayoutGuide.topAnchor : containerView.topAnchor,
                    constant: needsSafeTop ? 8 : -28
                ),
                closeButton.leftAnchor.constraint(equalTo: containerView.rightAnchor, constant: -12),
            ]

        default:
            closePositionConstraints = [
                closeButton.topAnchor.constraint(equalTo: safeTopAnchor, constant: 8),
                closeButton.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -8),
            ]
        }

        NSLayoutConstraint.activate(closePositionConstraints)

        switch close.type ?? "icon" {
        case "text":
            applyCloseText(close.text)
        default:
            applyCloseIcon(close.icon)
        }
    }

    private func applyCloseIcon(_ icon: CustomInAppPayload.Layout.Close.Icon?) {
        closeButton.setTitle(nil, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        closeButton.layer.cornerRadius = 18
        closeButton.layer.masksToBounds = true
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        var systemImageName = "xmark"
        if icon?.style == "outlined" {
            systemImageName = "xmark.circle"
        } else if icon?.style == "filled" {
            systemImageName = "xmark.circle.fill"
        }

        closeButton.setImage(UIImage(systemName: systemImageName), for: .normal)
        closeButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 18, weight: .bold),
            forImageIn: .normal
        )

        if let hex = icon?.color, let color = UIColor(hex: hex) {
            closeButton.tintColor = color
        } else {
            closeButton.tintColor = .black
        }
    }

    private func applyCloseText(_ textData: CustomInAppPayload.Layout.Close.CloseText?) {
        closeButton.setImage(nil, for: .normal)
        closeButton.backgroundColor = .clear
        closeButton.layer.cornerRadius = 0
        closeButton.layer.masksToBounds = false
        closeButton.contentEdgeInsets = .zero

        var title = textData?.label?.localize(defaultLang)
        if let dict = textData?.label {
            title = dict.localize(defaultLang, fallback: "Close")
        }
        closeButton.setTitle(title, for: .normal)

        if let colorHex = textData?.color, let color = UIColor(hex: colorHex) {
            closeButton.setTitleColor(color, for: .normal)
        }

        if let fontSize = textData?.fontSize {
            closeButton.titleLabel?.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        }
    }

    private func applyOverlayForCurrentLayout() {
        overlayView.gestureRecognizers?.forEach { overlayView.removeGestureRecognizer($0) }
        overlayView.isUserInteractionEnabled = false
        overlayView.backgroundColor = .clear

        guard let extra = currentLayout?.extra else { return }

        if let overlayColorHex = extra.overlay?.color,
           let color = UIColor(hex: overlayColorHex) {
            overlayView.backgroundColor = color.withAlphaComponent(0.5)
        }

        if extra.overlay?.action == "close" {
            overlayView.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleOverlayClose))
            overlayView.addGestureRecognizer(tapGesture)
        }
    }

    private func applyTransition() {
        guard let transitionType = currentLayout?.extra?.transition ?? layouts.first?.extra?.transition else {
            return
        }

        switch transitionType {
        case "right-to-left":
            containerView.transform = CGAffineTransform(translationX: view.bounds.width, y: 0)
        case "left-to-right":
            containerView.transform = CGAffineTransform(translationX: -view.bounds.width, y: 0)
        case "top-to-bottom":
            containerView.transform = CGAffineTransform(translationX: 0, y: -view.bounds.height)
        case "bottom-to-top":
            containerView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
        case "no-transition":
            containerView.transform = .identity
            return
        default:
            containerView.transform = .identity
            return
        }

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            self.containerView.transform = .identity
        }
    }

    // MARK: - Page building

    private func buildPageView(_ layout: CustomInAppPayload.Layout) -> UIView {
        let pageView = UIView()
        pageView.clipsToBounds = true

        applyPageBackground(on: pageView, style: layout.style)

        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.backgroundColor = .clear
        pageView.addSubview(contentContainer)

        if isFullscreen {
            // Carousel slide parity with single fullscreen: each slide gets
            // a min-inset + 4% ratio padding on every edge so notch-less
            // devices still have breathing room AND notched devices stay
            // clear of the Dynamic Island. Bottom padding additionally
            // reserves space for the carousel bottom bar (page control +
            // arrows). Mirrors StyleViewController fullscreen branch.
            let screenSize = UIScreen.main.bounds
            let fullscreenInnerH = screenSize.width * fullscreenInnerHorizontalPaddingRatio
            let fullscreenInnerV = screenSize.height * fullscreenInnerVerticalPaddingRatio
            let topPadding = max(view.safeAreaInsets.top, fullscreenMinTopInset) + fullscreenInnerV
            let bottomPadding = max(view.safeAreaInsets.bottom, fullscreenMinBottomInset)
                + fullscreenInnerV
                + fullscreenBottomChromeHeight
            NSLayoutConstraint.activate([
                contentContainer.topAnchor.constraint(equalTo: pageView.topAnchor, constant: topPadding),
                contentContainer.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: fullscreenInnerH),
                contentContainer.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -fullscreenInnerH),
                contentContainer.bottomAnchor.constraint(equalTo: pageView.bottomAnchor, constant: -bottomPadding),
            ])
        } else {
            // Carousel slide parity with single modal: ratio-based inner
            // padding on every edge (5% width / 5% height) so the same
            // proportions render on every device. Mirrors StyleViewController
            // modal default branch.
            let modalHeightPt = UIScreen.main.bounds.height * modalHeightRatio
            let modalWidthPt = UIScreen.main.bounds.width * modalWidthRatio
            let innerH = modalWidthPt * modalInnerHorizontalPaddingRatio
            let innerV = modalHeightPt * modalInnerVerticalPaddingRatio
            NSLayoutConstraint.activate([
                contentContainer.topAnchor.constraint(equalTo: pageView.topAnchor, constant: innerV),
                contentContainer.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: innerH),
                contentContainer.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -innerH),
                contentContainer.bottomAnchor.constraint(equalTo: pageView.bottomAnchor, constant: -innerV),
            ])
        }

        let contentScrollView = UIScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.showsVerticalScrollIndicator = false
        contentScrollView.showsHorizontalScrollIndicator = false
        contentScrollView.backgroundColor = .clear
        contentScrollView.isScrollEnabled = isFullscreen
        contentScrollView.alwaysBounceVertical = isFullscreen
        contentScrollView.bounces = isFullscreen
        contentContainer.addSubview(contentScrollView)

        let contentStackView = UIStackView()
        contentStackView.axis = .vertical
        contentStackView.spacing = 0
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        let hasFlexibleSpacerBlock = layout.blocks?.order?.contains(where: { block in
            if case .spacer(let spacerBlock) = block {
                return spacerBlock.fillAvailableSpacing == true
            }
            return false
        }) ?? false

        let rootContentStack: UIStackView
        if hasFlexibleSpacerBlock {
            rootContentStack = contentStackView
        } else {
            let topSpacer = UIView()
            topSpacer.translatesAutoresizingMaskIntoConstraints = false
            topSpacer.backgroundColor = .clear
            topSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
            topSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

            let bottomSpacer = UIView()
            bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
            bottomSpacer.backgroundColor = .clear
            bottomSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
            bottomSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

            let layoutStack = UIStackView(arrangedSubviews: [topSpacer, contentStackView, bottomSpacer])
            layoutStack.axis = .vertical
            layoutStack.spacing = 0
            layoutStack.alignment = .fill
            layoutStack.distribution = .fill
            layoutStack.translatesAutoresizingMaskIntoConstraints = false
            applyContentAlignment(layout.blocks?.align, topSpacer: topSpacer, bottomSpacer: bottomSpacer)
            rootContentStack = layoutStack
        }

        contentScrollView.addSubview(rootContentStack)

        NSLayoutConstraint.activate([
            contentScrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            rootContentStack.topAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.topAnchor),
            rootContentStack.leadingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.leadingAnchor),
            rootContentStack.trailingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.trailingAnchor),
            rootContentStack.bottomAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.bottomAnchor),
            rootContentStack.widthAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.widthAnchor),
            rootContentStack.heightAnchor.constraint(greaterThanOrEqualTo: contentScrollView.frameLayoutGuide.heightAnchor),
        ])

        var flexibleSpacerViews: [UIView] = []

        if let orderArray = layout.blocks?.order {
            for block in orderArray {
                var blockView: UIView?
                // Carousel slide parity with single: per-block marginTop /
                // marginBottom are PERCENTS of container height (0–100).
                // Resolved + applied via wrapBlockWithMargins below.
                var marginTop: Int? = nil
                var marginBottom: Int? = nil
                switch block {
                case .text(let tb):
                    blockView = renderTextBlock(tb)
                    marginTop = tb.marginTop
                    marginBottom = tb.marginBottom
                case .image(let ib):
                    blockView = renderImageBlock(ib)
                    marginTop = ib.marginTop
                    marginBottom = ib.marginBottom
                case .spacer(let sb):
                    let spacerView = renderSpacerBlock(sb)
                    if sb.fillAvailableSpacing == true {
                        flexibleSpacerViews.append(spacerView)
                    }
                    blockView = spacerView
                    marginTop = sb.marginTop
                    marginBottom = sb.marginBottom
                case .button(let bb):
                    blockView = renderButtonBlock(bb)
                case .buttonGroup(let bg):
                    blockView = renderButtonGroupBlock(bg)
                    marginTop = bg.marginTop
                    marginBottom = bg.marginBottom
                case .unknown:
                    continue
                }

                if let view = blockView {
                    contentStackView.addArrangedSubview(
                        wrapBlockWithMargins(view, marginTop: marginTop, marginBottom: marginBottom)
                    )
                }
            }
        }

        if flexibleSpacerViews.count > 1 {
            let referenceSpacer = flexibleSpacerViews[0]
            for spacer in flexibleSpacerViews.dropFirst() {
                spacer.heightAnchor.constraint(equalTo: referenceSpacer.heightAnchor).isActive = true
            }
        }

        return pageView
    }

    private func applyContentAlignment(_ align: String?, topSpacer: UIView, bottomSpacer: UIView) {
        let normalized = (align ?? "top").lowercased()

        switch normalized {
        case "center":
            NSLayoutConstraint.activate([
                topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0),
                bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0),
                topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor),
            ])
        case "bottom":
            NSLayoutConstraint.activate([
                topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0),
                bottomSpacer.heightAnchor.constraint(equalToConstant: 0),
            ])
        default:
            NSLayoutConstraint.activate([
                topSpacer.heightAnchor.constraint(equalToConstant: 0),
                bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0),
            ])
        }
    }

    private func applyPageBackground(on pageView: UIView, style: CustomInAppPayload.Layout.Style?) {
        if let bgColorHex = style?.bgColor,
           let color = UIColor(hex: bgColorHex) {
            pageView.backgroundColor = color
        }

        // bgImage is OPTIONAL — apply only when a non-empty URL is set.
        // Previously this branch early-returned, which silently skipped
        // the bottom-strip render below for any slide without a bgImage
        // (bgBottomInset / bgBottomColor / bgBottomRadiusTop all dropped).
        if let bgImageURL = style?.bgImage, !bgImageURL.isEmpty {
            let bgImageView = UIImageView()
            bgImageView.translatesAutoresizingMaskIntoConstraints = false
            bgImageView.contentMode = .scaleAspectFill
            bgImageView.clipsToBounds = true

            pageView.insertSubview(bgImageView, at: 0)

            NSLayoutConstraint.activate([
                bgImageView.topAnchor.constraint(equalTo: pageView.topAnchor),
                bgImageView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                bgImageView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                bgImageView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),
            ])

            if let url = URL(string: bgImageURL) {
                if let cached = PaylisherImageCache.shared.cachedImage(for: url) {
                    bgImageView.image = cached
                } else {
                    PaylisherImageCache.shared.image(for: url) { image in
                        if let image = image { bgImageView.image = image }
                    }
                }
            }

            if style?.bgImageMask == true,
               let maskColorHex = style?.bgImageColor {
                let maskView = UIView()
                maskView.translatesAutoresizingMaskIntoConstraints = false
                maskView.backgroundColor = UIColor(hex: maskColorHex)?.withAlphaComponent(0.5)
                bgImageView.addSubview(maskView)

                NSLayoutConstraint.activate([
                    maskView.topAnchor.constraint(equalTo: bgImageView.topAnchor),
                    maskView.leadingAnchor.constraint(equalTo: bgImageView.leadingAnchor),
                    maskView.trailingAnchor.constraint(equalTo: bgImageView.trailingAnchor),
                    maskView.bottomAnchor.constraint(equalTo: bgImageView.bottomAnchor),
                ])
            }
        }

        // Carousel slide parity with single modal/fullscreen: per-slide
        // bottom strip (`bgBottomInset` height + `bgBottomColor` fill +
        // `bgBottomRadiusTop` top radius). Strip sits ABOVE bgImage and
        // BELOW the slide's contentContainer so authored content overlaps
        // the strip naturally. Mirrors StyleViewController.addBottomStripIfNeeded.
        // Now runs for EVERY slide regardless of whether bgImage is set.
        addBottomStripIfNeeded(on: pageView, style: style)
    }

    /// Add the bottom decorative strip to a carousel slide. Reads
    /// `bgBottomInset` (PERCENT of container height), `bgBottomColor`
    /// (falls back to `bgColor`), and `bgBottomRadiusTop` (PERCENT of
    /// container height, top-left + top-right corners only). All three
    /// fields are authored per-slide in Studio.
    private func addBottomStripIfNeeded(
        on pageView: UIView,
        style: CustomInAppPayload.Layout.Style?
    ) {
        guard let style = style else { return }
        let rawValue = CGFloat(style.bgBottomInset ?? 0)
        let bottomInset: CGFloat = {
            let clampedPct = clampPct(rawValue)
            return currentContainerHeight() * clampedPct / 100
        }()
        guard bottomInset > 0 else { return }

        let stripColorHex = style.bgBottomColor ?? style.bgColor
        guard let hex = stripColorHex, let color = UIColor(hex: hex) else { return }

        let rawTopRadius = CGFloat(style.bgBottomRadiusTop ?? 0)
        let topRadius: CGFloat = {
            let pct = clampPct(rawTopRadius)
            return currentContainerHeight() * pct / 100
        }()

        let stripView = UIView()
        stripView.translatesAutoresizingMaskIntoConstraints = false
        stripView.backgroundColor = color
        if topRadius > 0 {
            stripView.layer.cornerRadius = topRadius
            stripView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            stripView.layer.masksToBounds = true
        }
        // Insert below contentContainer (which is added AFTER applyPageBackground
        // returns) but above bgImage. Subview index doesn't strictly matter
        // because contentContainer gets added last and ends up on top.
        pageView.addSubview(stripView)
        NSLayoutConstraint.activate([
            stripView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
            stripView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
            stripView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),
            stripView.heightAnchor.constraint(equalToConstant: bottomInset),
        ])
    }

    // MARK: - Navigation

    @objc private func didTapPrev() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        scrollToCurrentIndex(animated: true)
    }

    @objc private func didTapNext() {
        guard currentIndex < layouts.count - 1 else { return }
        currentIndex += 1
        scrollToCurrentIndex(animated: true)
    }

    private func scrollToCurrentIndex(animated: Bool) {
        let offset = CGPoint(x: pageScrollView.bounds.width * CGFloat(currentIndex), y: 0)
        pageScrollView.setContentOffset(offset, animated: animated)
        updateSlideChrome()
    }

    private func updateArrows() {
        guard layouts.count > 1 else {
            prevArrow.isHidden = true
            nextArrow.isHidden = true
            return
        }

        let arrowsEnabled = layouts.contains { layout in
            layout.style?.navigationalArrows == true
        }
        guard arrowsEnabled else {
            prevArrow.isHidden = true
            nextArrow.isHidden = true
            return
        }

        prevArrow.isHidden = currentIndex == 0
        nextArrow.isHidden = currentIndex == layouts.count - 1
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === pageScrollView, pageScrollView.bounds.width > 0 else { return }
        currentIndex = max(0, min(layouts.count - 1, Int(round(scrollView.contentOffset.x / pageScrollView.bounds.width))))
        updateSlideChrome()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === pageScrollView, pageScrollView.bounds.width > 0 else { return }
        currentIndex = max(0, min(layouts.count - 1, Int(round(scrollView.contentOffset.x / pageScrollView.bounds.width))))
        updateSlideChrome()
    }

    @objc private func didTapClose() {
        dismissInApp(via: "closeButton")
    }

    @objc private func handleOverlayClose() {
        dismissInApp(via: "overlay")
    }

    private func captureButtonClick(action: String, type: String, label: String? = nil) {
        var properties: [String: Any?] = [
            "action": action,
            "type": type,
        ]
        if let label, !label.isEmpty {
            properties["label"] = label
        }

        PaylisherNotificationEventTracker.capture(
            "inappMessageButtonClick",
            pushId: pushId,
            properties: properties
        )
    }

    private func dismissInApp(via: String) {
        PaylisherNotificationEventTracker.capture(
            "inappMessageClose",
            pushId: pushId,
            properties: ["via": via]
        )

        guard let transitionType = currentLayout?.extra?.transition ?? layouts.first?.extra?.transition else {
            dismiss(animated: true)
            return
        }

        UIView.animate(withDuration: 0.3, animations: {
            switch transitionType {
            case "right-to-left":
                self.containerView.transform = CGAffineTransform(translationX: self.view.bounds.width, y: 0)
            case "left-to-right":
                self.containerView.transform = CGAffineTransform(translationX: -self.view.bounds.width, y: 0)
            case "top-to-bottom":
                self.containerView.transform = CGAffineTransform(translationX: 0, y: -self.view.bounds.height)
            case "bottom-to-top":
                self.containerView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
            default:
                self.containerView.transform = .identity
            }
        }, completion: { _ in
            self.dismiss(animated: false)
        })
    }

    // MARK: - Block Rendering

    /// Wrap a block view with per-block top + bottom margins. Carousel
    /// percent parity: marginTop / marginBottom are PERCENTS of container
    /// height (0–100). Returns the original blockView when both margins
    /// are 0 to avoid an extra UIView in the hierarchy. Mirrors
    /// StyleViewController.wrapBlockWithMargins.
    private func wrapBlockWithMargins(_ blockView: UIView, marginTop: Int?, marginBottom: Int?) -> UIView {
        let top = bannerPctV(CGFloat(marginTop ?? 0))
        let bottom = bannerPctV(CGFloat(marginBottom ?? 0))
        if top == 0 && bottom == 0 { return blockView }
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        blockView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(blockView)
        NSLayoutConstraint.activate([
            blockView.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: top),
            blockView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -bottom),
            blockView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            blockView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
        ])
        return wrapper
    }

    private func renderTextBlock(_ block: CustomInAppPayload.Layout.Blocks.TextBlock) -> UIView {
        let label = UILabel()
        label.text = block.content?.localize(defaultLang) ?? ""
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        // Carousel slide percent parity: fontSize is a PERCENT of container
        // height (modal: 0.48 × screen.h; fullscreen: screen.h). Mirrors
        // StyleViewController.renderTextBlock.
        let scaledFontSize = scaledFontSizeString(block.fontSize)
        label.font = makeFont(
            family: block.fontFamily,
            weight: block.fontWeight,
            size: scaledFontSize,
            italic: block.italic == true
        )

        if block.underscore == true {
            let text = label.text ?? ""
            label.attributedText = NSAttributedString(string: text, attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: label.font as Any,
                .foregroundColor: UIColor(hex: block.color ?? "#000000") ?? .black,
            ])
        } else if let colorHex = block.color, let color = UIColor(hex: colorHex) {
            label.textColor = color
        }

        switch block.textAlignment {
        case "center":
            label.textAlignment = .center
        case "right":
            label.textAlignment = .right
        default:
            label.textAlignment = .left
        }

        // Carousel slide percent parity: horizontalMargin is a PERCENT of
        // container width. Modal/fullscreen also keep the legacy
        // `extraHorizontalInset` so a payload-authored 0% still gets a
        // small breathing inset — same contract StyleViewController uses.
        let scaledHorizontalMargin = bannerPctH(CGFloat(block.horizontalMargin ?? 0))
        let scaledVerticalPadding = scaleV(4)
        if (block.horizontalMargin ?? 0) > 0 {
            let adjustedMargin = scaledHorizontalMargin + extraHorizontalInset
            let wrapper = UIView()
            label.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(label)

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: scaledVerticalPadding),
                label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -scaledVerticalPadding),
                label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: adjustedMargin),
                label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -adjustedMargin),
            ])

            if let action = block.action, !action.isEmpty {
                let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapAction(_:)))
                wrapper.isUserInteractionEnabled = true
                wrapper.accessibilityIdentifier = action
                wrapper.accessibilityValue = "text"
                wrapper.addGestureRecognizer(tap)
            }

            return wrapper
        }

        let wrapper = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: scaledVerticalPadding),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -scaledVerticalPadding),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: contentHorizontalInset),
            label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -contentHorizontalInset),
        ])

        if let action = block.action, !action.isEmpty {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapAction(_:)))
            wrapper.isUserInteractionEnabled = true
            wrapper.accessibilityIdentifier = action
            wrapper.accessibilityValue = "text"
            wrapper.addGestureRecognizer(tap)
        }

        return wrapper
    }

    private func renderImageBlock(_ block: CustomInAppPayload.Layout.Blocks.ImageBlock) -> UIView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        // Match Studio preview + Android: image fills a fixed slot, crops overflow.
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        // Accessibility: expose `alt` to VoiceOver (mirrors StyleViewController).
        if let altText = block.alt, !altText.isEmpty {
            imageView.isAccessibilityElement = true
            imageView.accessibilityLabel = altText
            imageView.accessibilityTraits.insert(.image)
        } else {
            imageView.isAccessibilityElement = false
        }

        // Carousel slide percent parity: fullscreen image dominates (32% of
        // viewport, 72pt floor); modal uses 36% of modal height. Same
        // intrinsics StyleViewController.renderImageBlock applies.
        if isFullscreen {
            let fullscreenImageHeight = max(
                UIScreen.main.bounds.height * fullscreenImageHeightRatio,
                modalImageMinHeight
            )
            let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: fullscreenImageHeight)
            heightConstraint.priority = .required
            heightConstraint.isActive = true
        } else {
            let modalHeight = UIScreen.main.bounds.height * modalHeightRatio
            let imageHeight = max(modalHeight * modalImageHeightRatio, modalImageMinHeight)
            let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: imageHeight)
            heightConstraint.priority = .required
            heightConstraint.isActive = true
        }

        if let urlString = block.url, let url = URL(string: urlString) {
            if let cached = PaylisherImageCache.shared.cachedImage(for: url) {
                imageView.image = cached
            } else {
                PaylisherImageCache.shared.image(for: url) { image in
                    if let image = image { imageView.image = image }
                }
            }
        }

        // Image sits inside the container's inner padding (applied at the
        // scrollView level). `block.margin` is an ADDITIONAL inset on top
        // of that. Fullscreen with `margin <= 0` falls back to a baseline
        // horizontal inset so the image doesn't run flush to system safe
        // areas — same contract StyleViewController uses.
        let rawMargin = CGFloat(block.margin ?? 0)
        let horizontalMargin: CGFloat = {
            return (isFullscreen && rawMargin <= 0) ? baseHorizontalInset : rawMargin
        }()

        let wrapper = UIView()
        let frameView = UIView()
        frameView.translatesAutoresizingMaskIntoConstraints = false
        frameView.clipsToBounds = true

        // Carousel slide percent parity: image radius is a PERCENT of
        // container height. Mirrors StyleViewController.renderImageBlock.
        if let radius = block.radius {
            frameView.layer.cornerRadius = bannerPctV(CGFloat(radius))
        }

        wrapper.addSubview(frameView)
        frameView.addSubview(imageView)

        NSLayoutConstraint.activate([
            frameView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            frameView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            frameView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: horizontalMargin),
            frameView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -horizontalMargin),

            imageView.topAnchor.constraint(equalTo: frameView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
        ])

        if let link = block.link, !link.isEmpty {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapAction(_:)))
            wrapper.isUserInteractionEnabled = true
            wrapper.accessibilityIdentifier = link
            wrapper.accessibilityValue = "image"
            wrapper.addGestureRecognizer(tap)
        }

        return wrapper
    }

    private func renderSpacerBlock(_ block: CustomInAppPayload.Layout.Blocks.SpacerBlock) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        if block.fillAvailableSpacing == true {
            spacer.setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
            spacer.setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
            return spacer
        }

        // Carousel slide percent parity: verticalSpacing is a PERCENT of
        // container height. Mirrors StyleViewController.renderSpacerBlock.
        let rawValue = CGFloat(block.verticalSpacing ?? 8)
        let height: CGFloat = {
            let pct = clampPct(rawValue)
            return currentContainerHeight() * pct / 100
        }()
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    private func renderButtonBlock(_ block: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock) -> UIView {
        // Carousel slide percent parity: `block.margin` is a HORIZONTAL-ONLY
        // outer spacing — PERCENT of container width. Mirrors
        // StyleViewController.renderButtonBlock.
        let marginH = bannerPctH(CGFloat(block.margin ?? 8))

        // Carousel slide percent parity: intrinsic button heights are scaled
        // vertically with the container. Same constants StyleViewController
        // uses (32 / 44 / 56pt iPhone-13 reference).
        let baseHeight: CGFloat
        switch block.verticalSize {
        case "small": baseHeight = 32
        case "large": baseHeight = 56
        default: baseHeight = 44
        }
        let heightValue: CGFloat = scaleV(baseHeight)

        let button = createStyledButton(block, buttonHeight: heightValue)
        let wrapper = UIView()
        button.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(button)
        button.layer.cornerRadius = resolveButtonCornerRadius(block, height: heightValue)

        var constraints = [
            button.topAnchor.constraint(equalTo: wrapper.topAnchor),
            button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: heightValue),
        ]

        let hSize = (block.horizontalSize ?? "").isEmpty ? "auto" : block.horizontalSize!
        let normalizedHSize: String
        switch hSize {
        case "large":
            normalizedHSize = "full"
        default:
            normalizedHSize = hSize
        }

        if normalizedHSize == "full" {
            // Full width — buttonPosition irrelevant. Horizontal margin
            // shrinks the button on both sides on top of the container's
            // inner padding (handled at scrollView level).
            constraints.append(button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: contentHorizontalInset + marginH))
            constraints.append(button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -(contentHorizontalInset + marginH)))
        } else {
            if normalizedHSize == "half" {
                // 50% of wrapper minus margin on each side.
                constraints.append(button.widthAnchor.constraint(equalTo: wrapper.widthAnchor, multiplier: 0.5, constant: -2 * marginH))
            } else {
                // auto — content-hugging width with min padding on either side.
                constraints.append(button.leadingAnchor.constraint(greaterThanOrEqualTo: wrapper.leadingAnchor, constant: contentHorizontalInset + marginH))
                constraints.append(button.trailingAnchor.constraint(lessThanOrEqualTo: wrapper.trailingAnchor, constant: -(contentHorizontalInset + marginH)))
                button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
            }

            switch block.buttonPosition {
            case "left":
                constraints.append(button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: contentHorizontalInset + marginH))
            case "right":
                constraints.append(button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -(contentHorizontalInset + marginH)))
            default:
                constraints.append(button.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor))
            }
        }

        NSLayoutConstraint.activate(constraints)
        return wrapper
    }

    private func renderButtonGroupBlock(_ block: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock) -> UIView {
        guard let buttons = block.buttons, !buttons.isEmpty else { return UIView() }

        let isHorizontal = block.buttonGroupType == "double-horizontal"

        // Vertical group: reuse single-button renderer so horizontalSize
        // (half/full/auto), buttonPosition and margins behave exactly like
        // single layouts. Mirrors StyleViewController.renderButtonGroupBlock.
        if !isHorizontal {
            let wrapper = UIView()
            let stack = UIStackView()
            stack.axis = .vertical
            // Carousel slide percent parity: vertical buttonGap is a
            // PERCENT of container height (0–100). Replaces previous
            // hardcoded `spacing = 0`.
            let rawGap = CGFloat(block.buttonGap ?? 0)
            stack.spacing = bannerPctV(rawGap)
            stack.alignment = .fill
            stack.distribution = .fill
            stack.translatesAutoresizingMaskIntoConstraints = false

            for buttonData in buttons {
                let buttonWrapper = renderButtonBlock(buttonData)
                stack.addArrangedSubview(buttonWrapper)
            }

            wrapper.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: wrapper.topAnchor),
                stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            ])

            return wrapper
        }

        let stack = UIStackView()
        stack.axis = .horizontal
        // Carousel slide percent parity: horizontal buttonGap is a PERCENT
        // of container WIDTH (vs % of height for vertical). Same authored
        // value, container-aware axis — replaces previous hardcoded 8pt.
        stack.spacing = bannerPctH(CGFloat(block.buttonGap ?? 0))
        stack.alignment = .center
        stack.distribution = .fillEqually

        for buttonData in buttons {
            // Carousel slide percent parity: button intrinsic heights are
            // scaled vertically with the container (32/44/56 iPhone-13 ref).
            let baseHeight: CGFloat
            switch buttonData.verticalSize {
            case "small": baseHeight = 32
            case "large": baseHeight = 56
            default: baseHeight = 44
            }
            let heightValue: CGFloat = scaleV(baseHeight)

            let btn = createStyledButton(buttonData, buttonHeight: heightValue)
            btn.layer.cornerRadius = resolveButtonCornerRadius(buttonData, height: heightValue)
            btn.heightAnchor.constraint(equalToConstant: heightValue).isActive = true

            // Wrap each button so per-button margin can shrink its width
            // and the stack's .fillEqually still splits the row 50/50.
            // Same construction StyleViewController uses for horizontal
            // button groups.
            let buttonWrapper = UIView()
            btn.translatesAutoresizingMaskIntoConstraints = false
            buttonWrapper.translatesAutoresizingMaskIntoConstraints = false
            buttonWrapper.addSubview(btn)
            // Carousel slide percent parity: per-button margin is a
            // PERCENT of container width.
            let buttonMargin = bannerPctH(CGFloat(buttonData.margin ?? 8))
            let hSize = (buttonData.horizontalSize ?? "").lowercased()
            // `auto` buttons sit at intrinsic width centered inside the
            // half wrapper. Other sizes stretch to wrapper edge (minus
            // margin). Same logic StyleViewController applies.
            if hSize == "auto" {
                btn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
                btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
                NSLayoutConstraint.activate([
                    btn.topAnchor.constraint(equalTo: buttonWrapper.topAnchor),
                    btn.bottomAnchor.constraint(equalTo: buttonWrapper.bottomAnchor),
                    btn.centerXAnchor.constraint(equalTo: buttonWrapper.centerXAnchor),
                    btn.leadingAnchor.constraint(greaterThanOrEqualTo: buttonWrapper.leadingAnchor, constant: buttonMargin),
                    btn.trailingAnchor.constraint(lessThanOrEqualTo: buttonWrapper.trailingAnchor, constant: -buttonMargin),
                ])
                stack.addArrangedSubview(buttonWrapper)
                continue
            }
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: buttonWrapper.topAnchor),
                btn.bottomAnchor.constraint(equalTo: buttonWrapper.bottomAnchor),
                btn.leadingAnchor.constraint(equalTo: buttonWrapper.leadingAnchor, constant: buttonMargin),
                btn.trailingAnchor.constraint(equalTo: buttonWrapper.trailingAnchor, constant: -buttonMargin),
            ])
            stack.addArrangedSubview(buttonWrapper)
        }

        let wrapper = UIView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)

        // No hardcoded vertical wrapper padding — per-block marginTop /
        // marginBottom carry user-controlled vertical spacing (handled at
        // the contentStackView level). Mirrors StyleViewController.
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: contentHorizontalInset),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -contentHorizontalInset),
        ])

        return wrapper
    }

    private func createStyledButton(
        _ block: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock,
        buttonHeight: CGFloat = 44
    ) -> UIButton {
        let button = UIButton(type: .system)
        let title = block.label?.localize(defaultLang) ?? ""
        button.setTitle(title, for: .normal)

        // Carousel slide percent parity: authored fontSize is a PERCENT of
        // CONTAINER height — same contract text blocks use. Matches
        // StyleViewController.createStyledButton. `buttonHeight` param kept
        // for future use (e.g. switching to button-relative font scaling).
        _ = buttonHeight
        let font = makeFont(
            family: block.fontFamily,
            weight: block.fontWeight,
            size: scaledFontSizeString(block.fontSize),
            italic: block.italic == true
        )
        button.titleLabel?.font = font

        if let hex = block.textColor, let color = UIColor(hex: hex) {
            button.setTitleColor(color, for: .normal)
        } else {
            button.setTitleColor(.white, for: .normal)
        }

        if let hex = block.backgroundColor, let color = UIColor(hex: hex) {
            button.backgroundColor = color
        }

        if let hex = block.borderColor, let color = UIColor(hex: hex) {
            button.layer.borderColor = color.cgColor
            button.layer.borderWidth = 1
        }

        // Carousel slide percent parity: borderRadius is a PERCENT of
        // container height (0–100). Mirrors StyleViewController.
        button.layer.cornerRadius = bannerPctV(CGFloat(block.borderRadius ?? 8))
        button.clipsToBounds = true

        let action = block.action ?? ""
        button.accessibilityIdentifier = action
        button.accessibilityValue = "button"
        button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)

        return button
    }

    private func resolveButtonCornerRadius(
        _ block: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock,
        height: CGFloat
    ) -> CGFloat {
        // Carousel slide percent parity: borderRadius PERCENT-of-container.
        // Capped at height/2 so it never exceeds a pill regardless of
        // authored value. Mirrors StyleViewController.
        let resolved = bannerPctV(CGFloat(block.borderRadius ?? 8))
        return min(resolved, height / 2)
    }

    private func makeFont(family: String?, weight: String?, size: String?, italic: Bool = false) -> UIFont {
        let rawSize = (size ?? "16").replacingOccurrences(of: "px", with: "")
        let fontSize = CGFloat(Double(rawSize) ?? 16)
        let normalizedWeight = (weight ?? "").lowercased()
        let isBold = normalizedWeight == "bold" || normalizedWeight == "bold_italic"
        let isItalic = italic || normalizedWeight == "italic" || normalizedWeight == "bold_italic"
        let fontWeight: UIFont.Weight = isBold ? .bold : .regular

        // Carousel slides resolve `default` to bundled Inter — exact same
        // contract as StyleViewController.makeFont so a carousel slide and
        // a single layout authored with identical text render identically.
        let normalizedFamily = family?.lowercased() ?? "default"
        switch normalizedFamily {
        case "monospace":
            let mono = UIFont.monospacedSystemFont(ofSize: fontSize, weight: fontWeight)
            if isItalic, let d = mono.fontDescriptor.withSymbolicTraits(mono.fontDescriptor.symbolicTraits.union(.traitItalic)) {
                return UIFont(descriptor: d, size: fontSize)
            }
            return mono
        case "default", "":
            return PaylisherFontRegistry.interFont(size: fontSize, bold: isBold, italic: isItalic)
        default:
            let baseFont = UIFont(name: family ?? "", size: fontSize)
                ?? .systemFont(ofSize: fontSize, weight: fontWeight)
            if isItalic, let d = baseFont.fontDescriptor.withSymbolicTraits(baseFont.fontDescriptor.symbolicTraits.union(.traitItalic)) {
                return UIFont(descriptor: d, size: fontSize)
            }
            return baseFont
        }
    }

    @objc private func handleButtonTap(_ sender: UIButton) {
        let action = sender.accessibilityIdentifier ?? ""
        captureButtonClick(action: action, type: "button", label: sender.currentTitle)
        handleBlockAction(action)
    }

    @objc private func handleTapAction(_ gesture: UITapGestureRecognizer) {
        let action = gesture.view?.accessibilityIdentifier ?? ""
        let type = gesture.view?.accessibilityValue ?? "button"
        captureButtonClick(action: action, type: type)
        handleBlockAction(action)
    }

    private func handleBlockAction(_ action: String) {
        if action.isEmpty || action == "close" {
            dismissInApp(via: "closeButton")
            return
        }

        if let url = URL(string: action) {
            UIApplication.shared.open(url)
        }
        dismissInApp(via: "intent")
    }
}
