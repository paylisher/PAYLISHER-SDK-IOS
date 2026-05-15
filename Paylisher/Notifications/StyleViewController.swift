//
//  StyleViewController.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 20.02.2025.
//

import UIKit

class StyleViewController: UIViewController {
    private let baseHorizontalInset: CGFloat = 16
    private let extraHorizontalInset: CGFloat = 6

    // Banner geometry — mirrors `lib/banner-layout-constants.ts` in the
    // Studio repo and `InAppMessageHelper.kt` / `InAppMessagingBanner.kt`
    // in the Android SDK. Keep these in sync — the same proportions must
    // render on every platform so banners look identical at any device size.
    private let bannerHeightRatio: CGFloat = 0.26
    private let bannerOuterHorizontalInsetRatio: CGFloat = 0.04
    private let bannerInnerHorizontalPaddingRatio: CGFloat = 0.04
    private let bannerInnerVerticalPaddingRatio: CGFloat = 0.04
    private let bannerOuterVerticalInsetRatio: CGFloat = 0.02

    // Modal geometry — mirrors `lib/modal-layout-constants.ts` (Studio) and
    // Android's `InAppMessageHelper.kt`. Modal is now ratio-driven the same
    // way banner is, so authored fields (margins, font sizes, gaps) read as
    // percents of modal geometry and the same proportions render on every
    // device.
    private let modalHeightRatio: CGFloat = 0.48
    private let modalWidthRatio: CGFloat = 0.88
    private let modalInnerHorizontalPaddingRatio: CGFloat = 0.05
    private let modalInnerVerticalPaddingRatio: CGFloat = 0.05
    private let modalImageHeightRatio: CGFloat = 0.36
    private let modalImageMinHeight: CGFloat = 72

    // Fullscreen geometry — mirrors `lib/fullscreen-layout-constants.ts`.
    // Same authoring contract as banner / modal: every authored field is a
    // percent of container geometry. Container here = full device viewport.
    // Min top/bottom insets are layered ON TOP OF the device's own safeArea
    // so a notch-less device still has breathing room — content lands in a
    // comfortable zone whether the phone has a notch / dynamic island or not.
    private let fullscreenInnerHorizontalPaddingRatio: CGFloat = 0.04
    private let fullscreenInnerVerticalPaddingRatio: CGFloat = 0.04
    private let fullscreenImageHeightRatio: CGFloat = 0.32
    private let fullscreenMinTopInset: CGFloat = 60
    private let fullscreenMinBottomInset: CGFloat = 50

    // Container content scale — authored pt values are interpreted against
    // an iPhone-13 reference container (banner: 358.8 × 219.44pt;
    // modal: 343.2 × 405.12pt; fullscreen: 390 × 844pt). Render time scales
    // them to the current device so visual proportions stay identical on
    // every device. Mirrors the Studio + Android helpers.
    private let bannerReferenceWidth: CGFloat = 358.8    // 390 * (1 - 2 * 0.04)
    private let bannerReferenceHeight: CGFloat = 219.44  // 844 * 0.26
    private var modalReferenceWidth: CGFloat { 390 * modalWidthRatio }   // 343.2
    private var modalReferenceHeight: CGFloat { 844 * modalHeightRatio } // 405.12
    private let fullscreenReferenceWidth: CGFloat = 390
    private let fullscreenReferenceHeight: CGFloat = 844

    private let style: CustomInAppPayload.Layout.Style
    
    private let close: CustomInAppPayload.Layout.Close
    
    private let extra: CustomInAppPayload.Layout.Extra
    
    private let blocks: CustomInAppPayload.Layout.Blocks

    private let layoutType: String
    private let pushId: String?

    private let containerView = UIView()

    private var containerHeightConstraint: NSLayoutConstraint?

    private let overlayView = UIView()

    private let arrowImageView = UIImageView()

    private let closeButton = UIButton(type: .system)

    private let scrollView = UIScrollView()
    private let contentStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 0
        sv.alignment = .fill
        sv.distribution = .fill
        return sv
    }()

    private let defaultLang: String

    private var contentHorizontalInset: CGFloat {
        // Banner / modal / fullscreen all apply their own ratio-based inner
        // horizontal padding at the scrollView level, so the per-block
        // wrappers must NOT add another inset on top — otherwise a `full`
        // width button or button-row would lose width to double padding.
        // Fallback (unknown layoutType) keeps the legacy 22pt inset.
        if layoutType == "banner" || layoutType == "modal" || layoutType == "fullscreen" { return 0 }
        return baseHorizontalInset + extraHorizontalInset
    }

    // MARK: - Container content scaling

    /// Whether this layout uses percent-based authoring. Banner / modal /
    /// fullscreen all do now — only unknown layoutTypes fall back to raw pt.
    private var isPercentContainer: Bool {
        return layoutType == "banner" || layoutType == "modal" || layoutType == "fullscreen"
    }

    /// Current container frame width (pt) — derived from the device screen
    /// and the container's outer geometry ratio.
    private func currentContainerWidth() -> CGFloat {
        if layoutType == "banner" {
            return UIScreen.main.bounds.width * (1 - 2 * bannerOuterHorizontalInsetRatio)
        }
        if layoutType == "modal" {
            return UIScreen.main.bounds.width * modalWidthRatio
        }
        return UIScreen.main.bounds.width
    }

    /// Current container frame height (pt).
    private func currentContainerHeight() -> CGFloat {
        if layoutType == "banner" {
            return UIScreen.main.bounds.height * bannerHeightRatio
        }
        if layoutType == "modal" {
            return UIScreen.main.bounds.height * modalHeightRatio
        }
        return UIScreen.main.bounds.height
    }

    /// Back-compat alias — banner-specific call sites still use this name.
    private func currentBannerWidth() -> CGFloat { return currentContainerWidth() }
    private func currentBannerHeight() -> CGFloat { return currentContainerHeight() }

    /// Reference width of the current container on the iPhone-13 baseline.
    private func referenceContainerWidth() -> CGFloat {
        if layoutType == "banner" { return bannerReferenceWidth }
        if layoutType == "modal" { return modalReferenceWidth }
        if layoutType == "fullscreen" { return fullscreenReferenceWidth }
        return UIScreen.main.bounds.width
    }
    /// Reference height of the current container on the iPhone-13 baseline.
    private func referenceContainerHeight() -> CGFloat {
        if layoutType == "banner" { return bannerReferenceHeight }
        if layoutType == "modal" { return modalReferenceHeight }
        if layoutType == "fullscreen" { return fullscreenReferenceHeight }
        return UIScreen.main.bounds.height
    }

    /// Scale a horizontal authored pt value (margins, horizontal insets) to
    /// the current container's coordinate space. No-op for fullscreen.
    private func scaleH(_ pt: CGFloat) -> CGFloat {
        guard isPercentContainer else { return pt }
        let scale = currentContainerWidth() / referenceContainerWidth()
        return pt * scale
    }

    /// Scale a vertical authored pt value (font size, image height, button
    /// height, spacers, vertical margins) to the current container's
    /// coordinate space. No-op for fullscreen.
    ///
    /// Kept for categorical / intrinsic renderer constants (image 60pt,
    /// button 32/44/56pt, group wrapper paddings). Authored fields go through
    /// `bannerPctH` / `bannerPctV` instead — they are now percent-based.
    private func scaleV(_ pt: CGFloat) -> CGFloat {
        guard isPercentContainer else { return pt }
        let scale = currentContainerHeight() / referenceContainerHeight()
        return pt * scale
    }

    // MARK: - Container percent helpers
    //
    // Authored payload spacing/sizing fields are expressed as a percent of
    // the current container's dimensions (0–100). Banner + modal share this
    // contract; fullscreen passes the raw pt through (legacy semantics).
    // Mirrors `bannerPctH/V` in Studio's `InAppReview.tsx` and the
    // `bannerPctVPx/HPx` helpers in the Android SDKs.

    private func clampPct(_ value: CGFloat) -> CGFloat {
        return max(0, min(100, value))
    }

    /// Resolve a percent value (0–100) to pt against the current container's
    /// width. Fullscreen returns the raw value (legacy pt). Name kept as
    /// `bannerPctH` for diff legibility — both banner and modal flow here.
    private func bannerPctH(_ raw: CGFloat) -> CGFloat {
        guard isPercentContainer else { return raw }
        return currentContainerWidth() * clampPct(raw) / 100
    }

    /// Same against the current container's height.
    private func bannerPctV(_ raw: CGFloat) -> CGFloat {
        guard isPercentContainer else { return raw }
        return currentContainerHeight() * clampPct(raw) / 100
    }

    /// Resolve an authored fontSize string (`"16"` / `"16px"`) — banner +
    /// modal treat it as a percent of container height, fullscreen returns
    /// it raw. Returns the same shape `makeFont` consumes. Used for TEXT
    /// blocks; button blocks now use `resolveButtonFontSizeString` instead
    /// so the font scales with the button itself, not the container.
    private func scaledFontSizeString(_ raw: String?) -> String? {
        guard let raw = raw else { return nil }
        guard isPercentContainer else { return raw }
        let trimmed = raw.replacingOccurrences(of: "px", with: "")
        guard let value = Double(trimmed) else { return raw }
        let resolved = bannerPctV(CGFloat(value))
        return String(format: "%g", Double(resolved))
    }

    /// Resolve a button's authored fontSize as a PERCENT of that button's
    /// own height. Banner + modal: same contract — `50` means "half of the
    /// button's height". Fullscreen returns the raw string for legacy pt
    /// semantics. Keeps the text inside the button regardless of container
    /// (a 10% value reads as 10% of 32/44/56pt, never 10% of a 405pt modal).
    private func resolveButtonFontSizeString(_ raw: String?, buttonHeight: CGFloat) -> String? {
        guard let raw = raw else { return nil }
        guard isPercentContainer else { return raw }
        let trimmed = raw.replacingOccurrences(of: "px", with: "")
        guard let value = Double(trimmed) else { return raw }
        let pct = max(0, min(100, CGFloat(value)))
        let resolved = buttonHeight * pct / 100
        return String(format: "%g", Double(resolved))
    }


    init(style: CustomInAppPayload.Layout.Style,
         close: CustomInAppPayload.Layout.Close,
         extra: CustomInAppPayload.Layout.Extra,
         blocks: CustomInAppPayload.Layout.Blocks,
         defaultLang: String,
         layoutType: String = "modal",
         pushId: String? = nil) {
        self.style = style
        self.close = close
        self.extra = extra
        self.blocks = blocks
        self.defaultLang = defaultLang
        self.layoutType = layoutType
        self.pushId = pushId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyTransition()

        if layoutType == "banner", let duration = extra.banner?.duration, duration > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) { [weak self] in
                self?.dismissInApp(via: "timeout")
            }
        }
    }

    
    func setupUI() {

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leftAnchor.constraint(equalTo: view.leftAnchor),
            overlayView.rightAnchor.constraint(equalTo: view.rightAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.isHidden = true

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

        containerView.addSubview(arrowImageView)

        // ScrollView + StackView for block content
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        let isContentScrollable = layoutType == "fullscreen"
        scrollView.isScrollEnabled = isContentScrollable
        scrollView.alwaysBounceVertical = isContentScrollable
        scrollView.bounces = isContentScrollable
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        // Common constraints for arrow
        NSLayoutConstraint.activate([
            arrowImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            arrowImageView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 8),
            arrowImageView.widthAnchor.constraint(equalToConstant: 32),
            arrowImageView.heightAnchor.constraint(equalToConstant: 32),

            // StackView fills scrollView content
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentStackView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        var centerYConstraint: NSLayoutConstraint?

        switch layoutType {
        case "fullscreen":
            // Fullscreen: container fills the screen. The scrollView is
            // inset by max(safeArea, fullscreenMinInset) on each axis so
            // notch-less devices still get a comfortable top/bottom inset,
            // plus a ratio-based horizontal + vertical padding for visual
            // breathing room (matches Studio + Android).
            let screenSize = UIScreen.main.bounds
            let fullscreenInnerH = screenSize.width * fullscreenInnerHorizontalPaddingRatio
            let fullscreenInnerV = screenSize.height * fullscreenInnerVerticalPaddingRatio
            // We resolve safeAreaInsets at layout time via the top-level
            // view, but UIKit only fills those after layout — using the
            // safeAreaLayoutGuide anchor plus our minimum constants gives
            // us the right behaviour on every device automatically.
            let topPadding = max(view.safeAreaInsets.top, fullscreenMinTopInset) + fullscreenInnerV
            let bottomPadding = max(view.safeAreaInsets.bottom, fullscreenMinBottomInset) + fullscreenInnerV
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: view.topAnchor),
                containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: topPadding),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: fullscreenInnerH),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -fullscreenInnerH),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -bottomPadding),
            ])

        case "banner":
            // Banner: floating pill, ratio-driven geometry so the visual
            // proportion is identical on every device. Width / inner pad /
            // outer pad are all multipliers of the device viewport rather
            // than fixed pt — mirrors Studio (`computeBannerGeometry`) and
            // Android SDK.
            let verticalPos = style.verticalPosition ?? "center"
            let screenSize = UIScreen.main.bounds
            let bannerHeight = screenSize.height * bannerHeightRatio
            let outerVerticalInset = screenSize.height * bannerOuterVerticalInsetRatio
            let innerHorizontalPadding = screenSize.width
                * (1 - 2 * bannerOuterHorizontalInsetRatio)
                * bannerInnerHorizontalPaddingRatio
            let innerVerticalPadding = bannerHeight * bannerInnerVerticalPaddingRatio

            NSLayoutConstraint.activate([
                containerView.widthAnchor.constraint(
                    equalTo: view.widthAnchor,
                    multiplier: 1 - 2 * bannerOuterHorizontalInsetRatio
                ),
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: innerHorizontalPadding),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -innerHorizontalPadding),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -innerVerticalPadding),
            ])

            switch verticalPos {
            case "top":
                containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: outerVerticalInset).isActive = true
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: innerVerticalPadding).isActive = true
            case "bottom":
                containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -outerVerticalInset).isActive = true
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: innerVerticalPadding).isActive = true
            default: // center
                containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: innerVerticalPadding).isActive = true
            }

            containerView.heightAnchor.constraint(equalToConstant: bannerHeight).isActive = true

        default:
            // Modal (default): centered, ratio-driven frame so the same
            // proportions render on every device — mirrors banner's contract.
            let cY = containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            cY.identifier = "containerCenterY"
            centerYConstraint = cY

            let modalHeightPt = UIScreen.main.bounds.height * modalHeightRatio
            let modalWidthPt = UIScreen.main.bounds.width * modalWidthRatio
            let innerHorizontalPadding = modalWidthPt * modalInnerHorizontalPaddingRatio
            let innerVerticalPadding = modalHeightPt * modalInnerVerticalPaddingRatio

            NSLayoutConstraint.activate([
                containerView.widthAnchor.constraint(
                    equalTo: view.widthAnchor,
                    multiplier: modalWidthRatio
                ),
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                cY,
                containerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: modalHeightRatio),

                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: innerVerticalPadding),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: innerHorizontalPadding),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -innerHorizontalPadding),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -innerVerticalPadding),
            ])
        }

        applyStyle(centerYConstraint: centerYConstraint)
        applyClose()
        applyOverlay()
        applyBlocks()
    }
    
   
    
   private func applyStyle(centerYConstraint: NSLayoutConstraint?) {

        if style.navigationalArrows == true {
            arrowImageView.image = UIImage(systemName: "arrow.left.square.fill")
            arrowImageView.tintColor = .blue
            arrowImageView.isHidden = false
        }

        if let bgColorHex = style.bgColor {
            containerView.backgroundColor = UIColor(hex: bgColorHex)
        }

        // Corner radius based on layout type
        if layoutType == "fullscreen" {
            containerView.layer.cornerRadius = 0
        } else if layoutType == "banner" {
            let radiusValue = CGFloat(style.radius ?? 35)
            containerView.layer.cornerRadius = radiusValue
        } else if layoutType == "modal" {
            containerView.layer.cornerRadius = 8
        } else {
            let radiusValue = CGFloat(style.radius ?? 8)
            containerView.layer.cornerRadius = radiusValue
        }

        containerView.clipsToBounds = true

        addBottomStripIfNeeded()

        if let bgImageStr = style.bgImage, !bgImageStr.isEmpty {
            addBackgroundImage(urlString: bgImageStr)
        }

        // Modal position is fixed to center by product rule.
    }

    private func addBottomStripIfNeeded() {
        // `bgBottomInset` is authored as a PERCENT of the container's height
        // (0–100) — same contract as Studio + Android. Banner / modal resolve
        // against the current container height; fullscreen passes raw pt
        // through so legacy layouts there stay unchanged.
        let rawValue = CGFloat(style.bgBottomInset ?? 0)
        let bottomInset: CGFloat = {
            if isPercentContainer {
                let clampedPct = max(0, min(100, rawValue))
                return currentContainerHeight() * clampedPct / 100
            }
            return rawValue
        }()
        guard bottomInset > 0 else { return }

        let stripColorHex = style.bgBottomColor ?? style.bgColor
        guard let hex = stripColorHex, let color = UIColor(hex: hex) else { return }

        // `bgBottomRadius` is authored as a PERCENT of container height —
        // rounds the strip's BOTTOM-LEFT + BOTTOM-RIGHT corners only (top
        // stays square so the strip seams flush against the content above).
        let rawBottomRadius = CGFloat(style.bgBottomRadius ?? 0)
        let bottomRadius: CGFloat = {
            if isPercentContainer {
                let pct = max(0, min(100, rawBottomRadius))
                return currentContainerHeight() * pct / 100
            }
            return rawBottomRadius
        }()

        let stripView = UIView()
        stripView.translatesAutoresizingMaskIntoConstraints = false
        stripView.backgroundColor = color
        if bottomRadius > 0 {
            stripView.layer.cornerRadius = bottomRadius
            stripView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            stripView.layer.masksToBounds = true
        }
        containerView.insertSubview(stripView, at: 0)
        NSLayoutConstraint.activate([
            stripView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stripView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stripView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            stripView.heightAnchor.constraint(equalToConstant: bottomInset)
        ])
    }
    
    private func applyClose() {

        // Banners dismiss via overlay tap or auto-timeout — no close button needed
        if layoutType == "banner" {
            closeButton.isHidden = true
            return
        }

        if close.active ?? true {

            closeButton.isHidden = false
        } else {

            closeButton.isHidden = true
        }
        
        let position = close.position ?? "right"

        // For fullscreen, use safeAreaLayoutGuide so the button clears the Dynamic Island.
        // Banner "top" no longer needs this — its containerView already starts at safeAreaLayoutGuide.
        let needsSafeTop = layoutType == "fullscreen"
        let safeTopAnchor: NSLayoutYAxisAnchor = needsSafeTop
            ? view.safeAreaLayoutGuide.topAnchor
            : containerView.topAnchor

        switch position {

        case "left":
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: safeTopAnchor, constant: 8),
                closeButton.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 8),
            ])

        case "right":
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: safeTopAnchor, constant: 8),
                closeButton.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -8),
            ])

        case "outside-left":
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: needsSafeTop ? view.safeAreaLayoutGuide.topAnchor : containerView.topAnchor, constant: needsSafeTop ? 8 : -28),
                closeButton.rightAnchor.constraint(equalTo: containerView.leftAnchor, constant: 12),
            ])

        case "outside-right":
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: needsSafeTop ? view.safeAreaLayoutGuide.topAnchor : containerView.topAnchor, constant: needsSafeTop ? 8 : -28),
                closeButton.leftAnchor.constraint(equalTo: containerView.rightAnchor, constant: -12),
            ])

        default:
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: safeTopAnchor, constant: 8),
                closeButton.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -8),
            ])
        }

        let closeType = close.type ?? "icon"
        switch closeType {
        case "text":
            applyCloseText(close.text)
        default:
            // Use icon as default so close button never becomes invisible because of missing type.
            applyCloseIcon(close.icon)
        }
        
    }
    
    private func applyCloseIcon(_ icon: CustomInAppPayload.Layout.Close.Icon?) {
        
        closeButton.setTitle(nil, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        closeButton.layer.cornerRadius = 18
        closeButton.layer.masksToBounds = true
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
               
               
               var systemImageName = "xmark"  // basic
               if icon?.style == "outlined" {
                   systemImageName = "xmark.circle"
               } else if icon?.style == "filled" {
                   systemImageName = "xmark.circle.fill"
               }
        
        let image = UIImage(systemName: systemImageName)
        
        closeButton.setImage(image, for: .normal)
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
        
        let lang = defaultLang
        
        var title = close.text?.label?[lang]
               if let dict = textData?.label {
                   title = dict[lang] ?? dict["en"] ?? "Close"
               }
               
               closeButton.setTitle(title, for: .normal)
        
        if let colorHex = textData?.color, let color = UIColor(hex: colorHex) {
                    closeButton.setTitleColor(color, for: .normal)
                }
                
                if let fontSizeStr = textData?.fontSize{
                    
                    let fontSizeVal = CGFloat(fontSizeStr)
                    
                    closeButton.titleLabel?.font = UIFont.systemFont(ofSize: fontSizeVal)
                }
        
    }
    
    
    private func addBackgroundImage(urlString: String) {
        let bgImageView = UIImageView()
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true

        containerView.insertSubview(bgImageView, at: 0)

        // Banner + modal: bgBottomInset is a percent of the container's
        // height (0–100). Fullscreen passes the raw pt through so legacy
        // layouts there stay unchanged.
        let rawBottomInset = CGFloat(style.bgBottomInset ?? 0)
        let bottomInset: CGFloat = {
            if isPercentContainer {
                let pct = max(0, min(100, rawBottomInset))
                return currentContainerHeight() * pct / 100
            }
            return rawBottomInset
        }()

        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -bottomInset)

        ])
        
        if let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        bgImageView.image = image
                        
                    }
                }
            }.resume()
        }
        
        if style.bgImageMask == true, let maskColorHex = style.bgImageColor {
            
              let overlayView = UIView()
              overlayView.translatesAutoresizingMaskIntoConstraints = false
              
             
              overlayView.backgroundColor = UIColor(hex: maskColorHex)?.withAlphaComponent(0.5)
             
              bgImageView.addSubview(overlayView)
              
              NSLayoutConstraint.activate([
                  overlayView.topAnchor.constraint(equalTo: bgImageView.topAnchor),
                  overlayView.leftAnchor.constraint(equalTo: bgImageView.leftAnchor),
                  overlayView.rightAnchor.constraint(equalTo: bgImageView.rightAnchor),
                  overlayView.bottomAnchor.constraint(equalTo: bgImageView.bottomAnchor)
              ])
          }
        
    }
    
    private func applyOverlay() {
        
        if extra.overlay?.action == "close" {
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleOverlayClose))
            overlayView.isUserInteractionEnabled = true
            overlayView.addGestureRecognizer(tapGesture)
        }
        
        if let overlayColorHex = extra.overlay?.color,
           let color = UIColor(hex: overlayColorHex) {
            overlayView.backgroundColor = color.withAlphaComponent(0.5)
        }
        
         
     }
    
    private func applyTransition() {
        guard let transitionType = extra.transition else {
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
        
        
        UIView.animate(withDuration: 0.2,
                       delay: 0,
                       options: .curveEaseInOut) {
            self.containerView.transform = .identity
        } completion: { _ in
            
        }
    }
    
    // MARK: - Block Rendering

    private func wrapBlockWithMargins(_ blockView: UIView, marginTop: Int?, marginBottom: Int?) -> UIView {
        // Banner: per-block vertical spacing is a PERCENT of banner height
        // (0–100). Modal / fullscreen keeps raw pt (legacy semantics).
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

    private func applyBlocks() {
        guard let orderArray = blocks.order else { return }

        let hasFlexibleSpacer = orderArray.contains {
            if case .spacer(let sb) = $0 { return sb.fillAvailableSpacing == true }
            return false
        }

        let topSpacer = UIView()
        let bottomSpacer = UIView()

        if !hasFlexibleSpacer {
            topSpacer.translatesAutoresizingMaskIntoConstraints = false
            bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
            contentStackView.addArrangedSubview(topSpacer)
        }

        for block in orderArray {
            var blockView: UIView?
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
                blockView = renderSpacerBlock(sb)
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
            if let v = blockView {
                contentStackView.addArrangedSubview(wrapBlockWithMargins(v, marginTop: marginTop, marginBottom: marginBottom))
            }
        }

        if !hasFlexibleSpacer {
            contentStackView.addArrangedSubview(bottomSpacer)
            applyContentAlignment(blocks.align, topSpacer: topSpacer, bottomSpacer: bottomSpacer)
        }
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
        default: // "top"
            NSLayoutConstraint.activate([
                topSpacer.heightAnchor.constraint(equalToConstant: 0),
                bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0),
            ])
        }
    }

    private func renderTextBlock(_ block: CustomInAppPayload.Layout.Blocks.TextBlock) -> UIView {
        let label = UILabel()
        label.text = block.content?[defaultLang] ?? block.content?.values.first ?? ""
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        // Banner: scale authored fontSize vertically with banner height.
        // Modal/fullscreen pass through unchanged (scaleV is no-op there).
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
                .foregroundColor: UIColor(hex: block.color ?? "#000000") ?? .black
            ])
        } else if let colorHex = block.color, let color = UIColor(hex: colorHex) {
            label.textColor = color
        }

        switch block.textAlignment {
        case "center": label.textAlignment = .center
        case "right": label.textAlignment = .right
        default: label.textAlignment = .left
        }

        // Banner: horizontalMargin is a PERCENT of banner width (0–100).
        // Modal/fullscreen pass through raw and add the legacy
        // `extraHorizontalInset` (see `adjustedMargin` below).
        let scaledHorizontalMargin = bannerPctH(CGFloat(block.horizontalMargin ?? 0))
        let scaledVerticalPadding = scaleV(4)
        if (block.horizontalMargin ?? 0) > 0 {
            let adjustedMargin = scaledHorizontalMargin + (layoutType == "banner" ? 0 : extraHorizontalInset)
            let wrapper = UIView()
            label.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: scaledVerticalPadding),
                label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -scaledVerticalPadding),
                label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: adjustedMargin),
                label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -adjustedMargin),
            ])
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
        // Match preview/Android behavior: image fills a fixed frame (cropping if needed).
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        // Accessibility: expose the alt text to VoiceOver, mirroring Android's
        // contentDescription wiring. Image becomes a VoiceOver-readable element
        // only when an alt text is provided.
        if let altText = block.alt, !altText.isEmpty {
            imageView.isAccessibilityElement = true
            imageView.accessibilityLabel = altText
            imageView.accessibilityTraits.insert(.image)
        } else {
            imageView.isAccessibilityElement = false
        }

        if layoutType == "banner" {
            // Banner image intrinsic height = 60pt on the iPhone 13 reference
            // banner; scale vertically so it stays proportional everywhere.
            let bannerImageHeight = scaleV(60)
            let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: bannerImageHeight)
            heightConstraint.priority = .required
            heightConstraint.isActive = true
        } else if layoutType == "fullscreen" {
            // Fullscreen image: 32% of the device viewport (image is meant
            // to dominate). 72pt floor matches modal so tiny devices never
            // collapse the image to nothing.
            let fullscreenImageHeight = max(
                UIScreen.main.bounds.height * fullscreenImageHeightRatio,
                modalImageMinHeight,
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
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        imageView.image = image
                    }
                }
            }.resume()
        }

        let rawMargin = CGFloat(block.margin ?? 0)
        // Image sits inside the container's inner padding like every other
        // block. `block.margin` is an additional inset on top of that padding.
        // Banner: percent-of-banner-width (0–100). Fullscreen keeps the
        // baseline pt inset so the image doesn't collide with system safe
        // areas when margin is 0.
        let horizontalMargin: CGFloat = {
            if layoutType == "banner" {
                return bannerPctH(rawMargin)
            }
            return (layoutType == "fullscreen" && rawMargin <= 0) ? baseHorizontalInset : rawMargin
        }()
        let verticalMargin: CGFloat = 0
        let leadingConstant: CGFloat = horizontalMargin
        let trailingConstant: CGFloat = -horizontalMargin
        let wrapper = UIView()
        let frameView = UIView()
        frameView.translatesAutoresizingMaskIntoConstraints = false
        frameView.clipsToBounds = true
        if let radius = block.radius {
            // Banner: image radius is a PERCENT of banner height (0–100).
            // Modal/fullscreen pass through raw pt.
            frameView.layer.cornerRadius = bannerPctV(CGFloat(radius))
        }

        wrapper.addSubview(frameView)
        frameView.addSubview(imageView)
        NSLayoutConstraint.activate([
            frameView.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: verticalMargin),
            frameView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -verticalMargin),
            frameView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: leadingConstant),
            frameView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: trailingConstant),

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
            spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
            spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            return spacer
        }

        // `verticalSpacing` is a PERCENT of the container's height (0–100)
        // for banner + modal. Fullscreen passes raw pt through.
        let rawValue = CGFloat(block.verticalSpacing ?? 8)
        let height: CGFloat = {
            if isPercentContainer {
                let pct = max(0, min(100, rawValue))
                return currentContainerHeight() * pct / 100
            }
            return rawValue
        }()
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    private func renderButtonBlock(_ block: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock) -> UIView {
        // `block.margin` is a HORIZONTAL-ONLY outer spacing — pads left/right
        // (and shrinks the button accordingly). Vertical gap between buttons
        // is controlled by per-block `marginTop` / `marginBottom`.
        // Banner: PERCENT of banner width (0–100). Modal/fullscreen: raw pt.
        let marginH = bannerPctH(CGFloat(block.margin ?? 8))

        // Resolve intrinsic button height BEFORE building the styled button —
        // the button's font is now a percent of its own height, so we need
        // the final height ready when `createStyledButton` is called.
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
            // Full width - buttonPosition is irrelevant. Horizontal margin
            // shrinks the button on both sides.
            constraints.append(button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: contentHorizontalInset + marginH))
            constraints.append(button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -(contentHorizontalInset + marginH)))
        } else {
            // half or auto: apply width then position
            if normalizedHSize == "half" {
                // 50% of wrapper minus margin on each side
                constraints.append(button.widthAnchor.constraint(equalTo: wrapper.widthAnchor, multiplier: 0.5, constant: -2 * marginH))
            } else {
                // auto: content-hugging size with min padding
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

        // For vertical groups, reuse single-button renderer so horizontalSize (half/full/auto),
        // buttonPosition and margins behave exactly like the preview payload contract.
        if !isHorizontal {
            let wrapper = UIView()
            let stack = UIStackView()
            stack.axis = .vertical
            // `buttonGap` is the inter-button vertical gap. Banner: percent of banner
            // height (0–100); modal/fullscreen passes raw pt straight through. Only
            // applied to vertical groups — horizontal groups stay 50/50 butted.
            let rawGap = CGFloat(block.buttonGap ?? 0)
            stack.spacing = bannerPctV(rawGap)
            stack.alignment = .fill
            stack.distribution = .fill
            stack.translatesAutoresizingMaskIntoConstraints = false

            for btnData in buttons {
                let buttonWrapper = renderButtonBlock(btnData)
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
        // Horizontal group: `buttonGap` is interpreted as % of container width
        // (vs % of container height for vertical groups). Same authored value,
        // container-aware axis — mirrors Studio + Android.
        stack.spacing = bannerPctH(CGFloat(block.buttonGap ?? 0))
        stack.alignment = .center
        stack.distribution = .fillEqually

        for btnData in buttons {
            let baseHeight: CGFloat
            switch btnData.verticalSize {
            case "small": baseHeight = 32
            case "large": baseHeight = 56
            default: baseHeight = 44
            }
            // Banner / modal: scale button intrinsic height with container height.
            let heightValue: CGFloat = scaleV(baseHeight)
            let btn = createStyledButton(btnData, buttonHeight: heightValue)
            btn.layer.cornerRadius = resolveButtonCornerRadius(btnData, height: heightValue)
            btn.heightAnchor.constraint(equalToConstant: heightValue).isActive = true

            // Wrap each button so per-button margin can shrink its width and the
            // stack's .fillEqually still splits the row 50/50 between wrappers.
            let buttonWrapper = UIView()
            btn.translatesAutoresizingMaskIntoConstraints = false
            buttonWrapper.translatesAutoresizingMaskIntoConstraints = false
            buttonWrapper.addSubview(btn)
            // Banner: per-button horizontal margin is a PERCENT of banner width
            // (0–100). Modal/fullscreen pass through raw pt.
            let buttonMargin = bannerPctH(CGFloat(btnData.margin ?? 8))
            let hSize = (btnData.horizontalSize ?? "").lowercased()
            // `auto` buttons sit at their intrinsic width inside the half
            // wrapper (centered) so the user can pair a wide button on one
            // side with a compact one on the other. Every other size stretches
            // the button to the wrapper edge (minus margin) — matches the
            // Studio + Android renderers.
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
        // No more hardcoded vertical wrapper padding. Each block already gets
        // its own per-block `marginTop` / `marginBottom` via `wrapBlockWithMargins`,
        // so the button group now butts up to the previous/next block by default
        // — the user controls the gap explicitly through those margins (banner:
        // percent of banner height; modal/fullscreen: raw pt).
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
        let title = block.label?[defaultLang] ?? block.label?.values.first ?? ""
        button.setTitle(title, for: .normal)

        // Banner + modal: authored fontSize is a PERCENT of CONTAINER height —
        // same contract text blocks use. Fullscreen keeps the raw string for
        // legacy pt semantics. (`buttonHeight` param kept for future use.)
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

        // Banner: borderRadius is a PERCENT of banner height (0–100).
        // Modal/fullscreen pass through raw pt.
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
        // Banner: borderRadius is a PERCENT of banner height (0–100).
        // Modal/fullscreen pass through raw pt. Cap at height/2 so the radius
        // never exceeds a "pill" shape regardless of authored value.
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

        guard let transitionType = extra.transition else {
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
            
            self.dismiss(animated: false, completion: nil)
        })
    }

    

  

}
