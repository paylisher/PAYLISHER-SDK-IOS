//
//  StyleViewController.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 20.02.2025.
//

import UIKit

class StyleViewController: UIViewController {
    private let modalHeightRatio: CGFloat = 0.48
    private let modalImageHeightRatio: CGFloat = 0.36
    private let modalImageMinHeight: CGFloat = 72
    private let baseHorizontalInset: CGFloat = 16
    private let extraHorizontalInset: CGFloat = 6

    private let style: CustomInAppPayload.Layout.Style
    
    private let close: CustomInAppPayload.Layout.Close
    
    private let extra: CustomInAppPayload.Layout.Extra
    
    private let blocks: CustomInAppPayload.Layout.Blocks

    private let layoutType: String

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
        baseHorizontalInset + extraHorizontalInset
    }


    init(style: CustomInAppPayload.Layout.Style,
         close: CustomInAppPayload.Layout.Close,
         extra: CustomInAppPayload.Layout.Extra,
         blocks: CustomInAppPayload.Layout.Blocks,
         defaultLang: String,
         layoutType: String = "modal") {
        self.style = style
        self.close = close
        self.extra = extra
        self.blocks = blocks
        self.defaultLang = defaultLang
        self.layoutType = layoutType
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
                self?.didTapClose()
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
            // Fullscreen: container fills the entire screen
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: view.topAnchor),
                containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

                scrollView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor),
            ])

        case "banner":
            // Banner: floating pill, fixed 26% height, position-aware
            let verticalPos = style.verticalPosition ?? "center"

            NSLayoutConstraint.activate([
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            ])

            switch verticalPos {
            case "top":
                containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16).isActive = true
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16).isActive = true
            case "bottom":
                containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16).isActive = true
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16).isActive = true
            default: // center
                containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16).isActive = true
            }

            // Fixed height: 26% of screen height
            containerView.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.height * 0.26).isActive = true

        default:
            // Modal (default): centered, screen-based frame
            let cY = containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            cY.identifier = "containerCenterY"
            centerYConstraint = cY

            NSLayoutConstraint.activate([
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
                cY,
                containerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: modalHeightRatio),

                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
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

        if let bgImageStr = style.bgImage, !bgImageStr.isEmpty {
            addBackgroundImage(urlString: bgImageStr)
        }

        // Modal position is fixed to center by product rule.
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
        
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            
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
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapClose))
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

    private func applyBlocks() {
        guard let orderArray = blocks.order else { return }

        for block in orderArray {
            var blockView: UIView?
            switch block {
            case .text(let tb):
                blockView = renderTextBlock(tb)
            case .image(let ib):
                blockView = renderImageBlock(ib)
            case .spacer(let sb):
                blockView = renderSpacerBlock(sb)
            case .button(let bb):
                blockView = renderButtonBlock(bb)
            case .buttonGroup(let bg):
                blockView = renderButtonGroupBlock(bg)
            case .unknown:
                continue
            }
            if let v = blockView {
                contentStackView.addArrangedSubview(v)
            }
        }
    }

    private func renderTextBlock(_ block: CustomInAppPayload.Layout.Blocks.TextBlock) -> UIView {
        let label = UILabel()
        label.text = block.content?[defaultLang] ?? block.content?.values.first ?? ""
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        let font = makeFont(family: block.fontFamily, weight: block.fontWeight, size: block.fontSize)
        if block.italic == true {
            label.font = UIFont.italicSystemFont(ofSize: font.pointSize)
        } else {
            label.font = font
        }

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

        if layoutType == "banner" {
            let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: 60)
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
        // Preview/Android contract: keep image inset on X axis only.
        let horizontalMarginBase: CGFloat = (layoutType == "fullscreen" && rawMargin <= 0) ? baseHorizontalInset : rawMargin
        let horizontalMargin: CGFloat = horizontalMarginBase + extraHorizontalInset
        let verticalMargin: CGFloat = 0
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
            frameView.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: verticalMargin),
            frameView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -verticalMargin),
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

        let height = CGFloat(block.verticalSpacing ?? 8)
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
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
            // Full width - buttonPosition is irrelevant
            constraints.append(button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: contentHorizontalInset))
            constraints.append(button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -contentHorizontalInset))
        } else {
            // half or auto: apply width then position
            if normalizedHSize == "half" {
                constraints.append(button.widthAnchor.constraint(equalTo: wrapper.widthAnchor, multiplier: 0.5))
            } else {
                // auto: content-hugging size with min padding
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

        // For vertical groups, reuse single-button renderer so horizontalSize (half/full/auto),
        // buttonPosition and margins behave exactly like the preview payload contract.
        if !isHorizontal {
            let wrapper = UIView()
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 0
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
        stack.spacing = 8
        stack.alignment = .fill
        stack.distribution = .fillEqually

        for btnData in buttons {
            let btn = createStyledButton(btnData)
            let heightValue: CGFloat
            switch btnData.verticalSize {
            case "small": heightValue = 32
            case "large": heightValue = 56
            default: heightValue = 44
            }
            btn.heightAnchor.constraint(equalToConstant: heightValue).isActive = true
            stack.addArrangedSubview(btn)
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

        let font = makeFont(family: block.fontFamily, weight: block.fontWeight, size: block.fontSize)
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
        button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)

        return button
    }

    private func makeFont(family: String?, weight: String?, size: String?) -> UIFont {
        let fontSize = CGFloat(Double(size ?? "16") ?? 16)
        let fontWeight: UIFont.Weight = weight == "bold" ? .bold : .regular

        switch family {
        case "monospace":
            return .monospacedSystemFont(ofSize: fontSize, weight: fontWeight)
        default:
            return .systemFont(ofSize: fontSize, weight: fontWeight)
        }
    }

    @objc private func handleButtonTap(_ sender: UIButton) {
        let action = sender.accessibilityIdentifier ?? ""
        handleBlockAction(action)
    }

    @objc private func handleTapAction(_ gesture: UITapGestureRecognizer) {
        let action = gesture.view?.accessibilityIdentifier ?? ""
        handleBlockAction(action)
    }

    private func handleBlockAction(_ action: String) {
        if action.isEmpty || action == "close" {
            didTapClose()
            return
        }

        if let url = URL(string: action) {
            UIApplication.shared.open(url)
        }
        didTapClose()
    }

    @objc private func didTapClose() {
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
