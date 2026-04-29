//
//  CarouselInAppViewController.swift
//  Paylisher
//

import UIKit

class CarouselInAppViewController: UIViewController, UIScrollViewDelegate {

    // MARK: - Properties

    private let modalHeightRatio: CGFloat = 0.48
    private let modalImageHeightRatio: CGFloat = 0.36
    private let modalImageMinHeight: CGFloat = 72
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
        baseHorizontalInset + extraHorizontalInset
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

        let position = close.position ?? "right"
        let resolvedPosition: String
        if !isFullscreen && (position == "outside-left" || position == "outside-right") {
            resolvedPosition = position == "outside-left" ? "left" : "right"
        } else {
            resolvedPosition = position
        }

        switch resolvedPosition {
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

        var title = textData?.label?[defaultLang]
        if let dict = textData?.label {
            title = dict[defaultLang] ?? dict["en"] ?? "Close"
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
            let bottomOffset = -fullscreenBottomChromeHeight
            NSLayoutConstraint.activate([
                contentContainer.topAnchor.constraint(equalTo: pageView.safeAreaLayoutGuide.topAnchor),
                contentContainer.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                contentContainer.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                contentContainer.bottomAnchor.constraint(equalTo: pageView.safeAreaLayoutGuide.bottomAnchor, constant: bottomOffset),
            ])
        } else {
            NSLayoutConstraint.activate([
                contentContainer.topAnchor.constraint(equalTo: pageView.topAnchor, constant: 16),
                contentContainer.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                contentContainer.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                contentContainer.bottomAnchor.constraint(equalTo: pageView.bottomAnchor, constant: -16),
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
                switch block {
                case .text(let tb):
                    blockView = renderTextBlock(tb)
                case .image(let ib):
                    blockView = renderImageBlock(ib)
                case .spacer(let sb):
                    let spacerView = renderSpacerBlock(sb)
                    if sb.fillAvailableSpacing == true {
                        flexibleSpacerViews.append(spacerView)
                    }
                    blockView = spacerView
                case .button(let bb):
                    blockView = renderButtonBlock(bb)
                case .buttonGroup(let bg):
                    blockView = renderButtonGroupBlock(bg)
                case .unknown:
                    continue
                }

                if let view = blockView {
                    contentStackView.addArrangedSubview(view)
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

        guard let bgImageURL = style?.bgImage, !bgImageURL.isEmpty else {
            return
        }

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
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        bgImageView.image = image
                    }
                }
            }.resume()
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

    private func renderTextBlock(_ block: CustomInAppPayload.Layout.Blocks.TextBlock) -> UIView {
        let label = UILabel()
        label.text = block.content?[defaultLang] ?? block.content?.values.first ?? ""
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        label.font = makeFont(
            family: block.fontFamily,
            weight: block.fontWeight,
            size: block.fontSize,
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

        let margin = CGFloat(block.horizontalMargin ?? 0)
        if margin > 0 {
            let adjustedMargin = margin + extraHorizontalInset
            let wrapper = UIView()
            label.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(label)

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 4),
                label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -4),
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
            label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -4),
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
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        let modalHeight = UIScreen.main.bounds.height * modalHeightRatio
        let imageHeight = max(modalHeight * modalImageHeightRatio, modalImageMinHeight)
        let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: imageHeight)
        heightConstraint.priority = .required
        heightConstraint.isActive = true

        if let urlString = block.url, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        imageView.image = image
                    }
                }
            }.resume()
        }

        let rawMargin = CGFloat(block.margin ?? 0)
        let horizontalMarginBase: CGFloat = (isFullscreen && rawMargin <= 0) ? baseHorizontalInset : rawMargin
        let horizontalMargin: CGFloat = horizontalMarginBase + extraHorizontalInset

        let wrapper = UIView()
        let frameView = UIView()
        frameView.translatesAutoresizingMaskIntoConstraints = false
        frameView.clipsToBounds = true

        if let radius = block.radius {
            frameView.layer.cornerRadius = CGFloat(radius)
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

        spacer.heightAnchor.constraint(equalToConstant: CGFloat(block.verticalSpacing ?? 8)).isActive = true
        return spacer
    }

    private func renderButtonBlock(_ block: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock) -> UIView {
        let button = createStyledButton(block)
        let margin = CGFloat(block.margin ?? 8)

        let wrapper = UIView()
        button.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(button)

        let heightValue: CGFloat
        switch block.verticalSize {
        case "small": heightValue = 32
        case "large": heightValue = 56
        default: heightValue = 44
        }
        button.layer.cornerRadius = resolveButtonCornerRadius(block, height: heightValue)

        var constraints = [
            button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: margin),
            button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -margin),
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
            constraints.append(button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: contentHorizontalInset))
            constraints.append(button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -contentHorizontalInset))
        } else {
            if normalizedHSize == "half" {
                constraints.append(button.widthAnchor.constraint(equalTo: wrapper.widthAnchor, multiplier: 0.5))
            } else {
                constraints.append(button.leadingAnchor.constraint(greaterThanOrEqualTo: wrapper.leadingAnchor, constant: contentHorizontalInset))
                constraints.append(button.trailingAnchor.constraint(lessThanOrEqualTo: wrapper.trailingAnchor, constant: -contentHorizontalInset))
                button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 24, bottom: 8, right: 24)
            }

            switch block.buttonPosition {
            case "left":
                constraints.append(button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: contentHorizontalInset))
            case "right":
                constraints.append(button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -contentHorizontalInset))
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

        if !isHorizontal {
            let wrapper = UIView()
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 0
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
        stack.spacing = 8
        stack.alignment = .fill
        stack.distribution = .fillEqually

        for buttonData in buttons {
            let button = createStyledButton(buttonData)
            let heightValue: CGFloat
            switch buttonData.verticalSize {
            case "small": heightValue = 32
            case "large": heightValue = 56
            default: heightValue = 44
            }
            button.layer.cornerRadius = resolveButtonCornerRadius(buttonData, height: heightValue)
            button.heightAnchor.constraint(equalToConstant: heightValue).isActive = true
            stack.addArrangedSubview(button)
        }

        let wrapper = UIView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: contentHorizontalInset),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -contentHorizontalInset),
        ])

        return wrapper
    }

    private func createStyledButton(_ block: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock) -> UIButton {
        let button = UIButton(type: .system)
        let title = block.label?[defaultLang] ?? block.label?.values.first ?? ""
        button.setTitle(title, for: .normal)

        let font = makeFont(
            family: block.fontFamily,
            weight: block.fontWeight,
            size: block.fontSize,
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

        button.layer.cornerRadius = CGFloat(block.borderRadius ?? 8)
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
        let requestedRadius = CGFloat(block.borderRadius ?? 8)
        return min(requestedRadius, height / 2)
    }

    private func makeFont(family: String?, weight: String?, size: String?, italic: Bool = false) -> UIFont {
        let rawSize = (size ?? "16").replacingOccurrences(of: "px", with: "")
        let fontSize = CGFloat(Double(rawSize) ?? 16)
        let normalizedWeight = (weight ?? "").lowercased()
        let isBold = normalizedWeight == "bold" || normalizedWeight == "bold_italic"
        let isItalic = italic || normalizedWeight == "italic" || normalizedWeight == "bold_italic"
        let fontWeight: UIFont.Weight = isBold ? .bold : .regular

        let baseFont: UIFont
        switch family?.lowercased() {
        case "monospace":
            baseFont = .monospacedSystemFont(ofSize: fontSize, weight: fontWeight)
        default:
            baseFont = .systemFont(ofSize: fontSize, weight: fontWeight)
        }

        guard isItalic,
              let descriptor = baseFont.fontDescriptor.withSymbolicTraits(
                baseFont.fontDescriptor.symbolicTraits.union(.traitItalic)
              ) else {
            return baseFont
        }

        return UIFont(descriptor: descriptor, size: fontSize)
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
