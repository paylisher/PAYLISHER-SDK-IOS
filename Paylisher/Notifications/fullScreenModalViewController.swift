
//
//  fullScreenModalViewController.swift
//  Paylisher
//
//  Created by elif uyar on 14.07.2025.
//
import UIKit

class fullScreenModalViewController: UIViewController {

    private let style: CustomInAppPayload.Layout.Style
    private let close: CustomInAppPayload.Layout.Close
    private let extra: CustomInAppPayload.Layout.Extra
    private let blocks: CustomInAppPayload.Layout.Blocks
    private let defaultLang: String

    private let overlayView = UIView()
    private let containerView = UIView()
    private let imageView = UIImageView()
    private let stackView = UIStackView()
    private let closeButton = UIButton(type: .system)
    
   

    init(style: CustomInAppPayload.Layout.Style,
         close: CustomInAppPayload.Layout.Close,
         extra: CustomInAppPayload.Layout.Extra,
         blocks: CustomInAppPayload.Layout.Blocks,
         defaultLang: String) {

        self.style = style
        self.close = close
        self.extra = extra
        self.blocks = blocks
        self.defaultLang = defaultLang
        

        super.init(nibName: nil, bundle: nil)

        self.modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyClose()
        applyBlocks()
        applyOverlay()
        applyBackground()
    }
    //status bar gizleniyor
    override var prefersStatusBarHidden: Bool {
        return true
    }
   
    private func setupUI() {
        
        view.addSubview(containerView)
            containerView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: view.topAnchor),
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            // 2. Köşe yuvarlama
            let containerRadius = min(style.radius ?? 0, 80)
            containerView.layer.cornerRadius = CGFloat(containerRadius)
            containerView.layer.masksToBounds = true

            if let radius = style.radius {
                imageView.layer.cornerRadius = CGFloat(radius)
                imageView.clipsToBounds = true
            }

            // 3. Overlay view (stackView'den önce ekleniyor, arka planda kalması için)
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(overlayView)
            NSLayoutConstraint.activate([
                overlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
                overlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                overlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                overlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            containerView.sendSubviewToBack(overlayView) // Arkaya al

            // 4. Stack View
            stackView.axis = .vertical
            stackView.spacing = 5
            stackView.alignment = .fill
            stackView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(stackView)

            var stackConstraints: [NSLayoutConstraint] = [
                stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
            ]

        
        // blocks.align değerine göre dikey konum
        switch blocks.align?.lowercased() {
        case "center":
            stackConstraints.append(stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor))
        case "bottom":
            stackConstraints.append(stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16))
        default:
            stackConstraints.append(stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16))
        }
            NSLayoutConstraint.activate(stackConstraints)
       
    }
    private func applyOverlay() {
        if extra.overlay?.action == "close" {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeModal))
            overlayView.isUserInteractionEnabled = true
            overlayView.addGestureRecognizer(tapGesture)
        }
        // Renk uygula
        if let hex = extra.overlay?.color,
           let color = UIColor(hex: hex) {
            overlayView.backgroundColor = color.withAlphaComponent(0.1)
        }
    }
    private func applyBackground() {
        if let bgImageUrlStr = style.bgImage,
           let url = URL(string: bgImageUrlStr) {

            let bgImageView = UIImageView()
            bgImageView.translatesAutoresizingMaskIntoConstraints = false
            bgImageView.contentMode = .scaleAspectFill
            bgImageView.clipsToBounds = true

            view.addSubview(bgImageView)

            NSLayoutConstraint.activate([
                bgImageView.topAnchor.constraint(equalTo: view.topAnchor),
                bgImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bgImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                bgImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        bgImageView.image = image
                    }
                }
            }.resume()
        }
        else if let hex = style.bgColor, let color = UIColor(hex: hex) {
            view.backgroundColor = color
        } else {
            view.backgroundColor = .white
        }
    }
    @objc private func closeModal() {
        dismiss(animated: true, completion: nil)
    }
   
      private func loadImage(from urlString: String) {
            guard let url = URL(string: urlString) else { return }

            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.imageView.image = image
                    }
                }
            }.resume()
        }
        // kapatma ikonunu özellikleri
        private func applyCloseIcon(_ icon: CustomInAppPayload.Layout.Close.Icon?) {
            closeButton.setTitle(nil, for: .normal)

            var systemImageName = "xmark" // default: basic
            if icon?.style == "outlined" {
                systemImageName = "xmark.circle"
            } else if icon?.style == "filled" {
                systemImageName = "xmark.circle.fill"
            }

            let image = UIImage(systemName: systemImageName)
            closeButton.setImage(image, for: .normal)

            if let hex = icon?.color, let color = UIColor(hex: hex) {
                closeButton.tintColor = color
            } else {
                closeButton.tintColor = .black
            }
        }
    private func applyClose() {
        // Eğer "active" false ise butonu gizle
        if close.active == false {
            closeButton.isHidden = true
            return
        }
        //üstüste geldiği için
        closeButton.removeFromSuperview()
        containerView.addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        // İkon stilini uygula
        applyCloseIcon(close.icon)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        var constraints: [NSLayoutConstraint] = [
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24)
        ]
        // Pozisyona göre hizalama
        if close.position == "left" {
            constraints.append(closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12))
        } else {
            constraints.append(closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12))
        }

        NSLayoutConstraint.activate(constraints)
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
   
    private func getTextAlignment(_ alignment: String?) -> NSTextAlignment {
        switch alignment?.lowercased() {
        case "left": return .left
        case "right": return .right
        case "center": return .center
        default: return .left
        }
    }
   
    private func createButton(from buttonData: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock) -> UIView {
        let button = UIButton(type: .system)
        
        // Title
        let title = buttonData.label?[defaultLang] ?? "Button"
        button.setTitle(title, for: .normal)
        
        // Font
        let fontSize = CGFloat(Double(buttonData.fontSize?.replacingOccurrences(of: "px", with: "") ?? "14") ?? 14)
        if let fontName = buttonData.fontFamily,
           let font = UIFont(name: fontName, size: fontSize) {
            button.titleLabel?.font = font
        } else if buttonData.fontWeight?.lowercased() == "bold" {
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: fontSize)
        } else if buttonData.fontWeight?.lowercased() == "italic" {
            button.titleLabel?.font = UIFont.italicSystemFont(ofSize: fontSize)
        } else {
            button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize)
        }

        // Underscore
        if buttonData.underscore == true {
            let attributedTitle = NSAttributedString(string: title, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
            button.setAttributedTitle(attributedTitle, for: .normal)
        }

        // Italic
        if buttonData.italic == true {
            button.titleLabel?.font = UIFont.italicSystemFont(ofSize: fontSize)
        }

        // Colors
        if let textHex = buttonData.textColor {
            button.setTitleColor(UIColor(hex: textHex), for: .normal)
        }

        if let bgHex = buttonData.backgroundColor {
            button.backgroundColor = UIColor(hex: bgHex)
        }

        if let borderHex = buttonData.borderColor {
            button.layer.borderColor = UIColor(hex: borderHex)?.cgColor
            button.layer.borderWidth = 1
        }

        button.layer.cornerRadius = CGFloat(buttonData.borderRadius ?? 0)
        button.clipsToBounds = true

        // Size
        var buttonWidth: CGFloat = 150
        var buttonHeight: CGFloat = 48

        switch buttonData.horizontalSize?.lowercased() {
        case "large": buttonWidth = 240
        case "medium": buttonWidth = 180
        case "small": buttonWidth = 120
        default: break
        }

        switch buttonData.verticalSize?.lowercased() {
        case "large": buttonHeight = 56
        case "medium": buttonHeight = 48
        case "small": buttonHeight = 40
        default: break
        }

        button.addAction(UIAction(handler: { [weak self] _ in
            self?.handleAction(buttonData.action)
        }), for: .touchUpInside)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        // Alignment
        button.contentHorizontalAlignment = {
            switch buttonData.buttonPosition?.lowercased() {
            case "left": return .left
            case "right": return .right
            case "centered": fallthrough
            default: return .center
            }
        }()

        // Margin
        let buttonMargin = CGFloat(buttonData.margin ?? 0)
        let buttonWrapperView = UIView()
        buttonWrapperView.translatesAutoresizingMaskIntoConstraints = false
        buttonWrapperView.layoutMargins = UIEdgeInsets(top: buttonMargin, left: buttonMargin, bottom: buttonMargin, right: buttonMargin)

        buttonWrapperView.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: buttonWrapperView.layoutMarginsGuide.topAnchor),
            button.bottomAnchor.constraint(equalTo: buttonWrapperView.layoutMarginsGuide.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: buttonWrapperView.layoutMarginsGuide.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: buttonWrapperView.layoutMarginsGuide.trailingAnchor),
            button.widthAnchor.constraint(equalToConstant: buttonWidth),
            button.heightAnchor.constraint(equalToConstant: buttonHeight)
        ])

        return buttonWrapperView
    }
    private func applySpacerBlock(_ block: CustomInAppPayload.Layout.Blocks.SpacerBlock) {
        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false

        // StackView'a önce ekleniyor
        stackView.addArrangedSubview(spacerView)

        if block.fillAvailableSpacing == true {
            spacerView.setContentHuggingPriority(.defaultLow, for: .vertical)
            spacerView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            //minimum 5pt yüksekliğe sahip olması sağlanıyor
            let minHeight: CGFloat = 5
            let heightConstraint = spacerView.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight)
            heightConstraint.priority = .defaultLow
            heightConstraint.isActive = true
        } else {
            let height: CGFloat
            if let spacingStr = block.verticalSpacing?.lowercased().replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespaces),
               let spacingValue = Double(spacingStr) {
                height = CGFloat(spacingValue)
            } else {
                height = 16
            }

            NSLayoutConstraint.activate([
                spacerView.heightAnchor.constraint(equalToConstant: height)
            ])
        }
    }
    
    private func setupSpacerBlocksIfNeeded() {
        blocks.order?.forEach {
            if case .spacer(let block) = $0 {
                applySpacerBlock(block)
            }
        }
    }
   
    private func applyBlocks() {
        blocks.order?.forEach { block in
            switch block {
            case .image(let imageBlock):
                applyImageBlock(imageBlock)

            case .text(let textBlock):
                applyTextBlock(textBlock)

            case .spacer(let spacerBlock):
                applySpacerBlock(spacerBlock)

            case .buttonGroup(let buttonGroupBlock):
                applyButtonGroupBlock(buttonGroupBlock)
            }
        }
    }
    private func applyImageBlock(_ block: CustomInAppPayload.Layout.Blocks.ImageBlock) {
        guard let imageUrl = block.url else { return }

        let margin = CGFloat(block.margin ?? 0)

        let imageWrapperView = UIView()
        imageWrapperView.translatesAutoresizingMaskIntoConstraints = false
        imageWrapperView.layoutMargins = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = CGFloat(block.radius ?? 0)
        imageView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ]

        imageWrapperView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: imageWrapperView.layoutMarginsGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageWrapperView.layoutMarginsGuide.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageWrapperView.layoutMarginsGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageWrapperView.layoutMarginsGuide.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 200)
        ])

        stackView.addArrangedSubview(imageWrapperView)

        loadImage(from: imageUrl)
    }
    
    private func applyTextBlock(_ block: CustomInAppPayload.Layout.Blocks.TextBlock) {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = getTextAlignment(block.textAlignment)
        label.text = block.content?[defaultLang] ?? "N/A"

        let fontSize = CGFloat(Double(block.fontSize?.replacingOccurrences(of: "px", with: "") ?? "16") ?? 16)

        if let fontName = block.fontFamily, let customFont = UIFont(name: fontName, size: fontSize) {
            label.font = customFont
        } else if block.fontWeight?.lowercased() == "bold" {
            label.font = UIFont.boldSystemFont(ofSize: fontSize)
        } else if block.fontWeight?.lowercased() == "italic" {
            label.font = UIFont.italicSystemFont(ofSize: fontSize)
        } else {
            label.font = UIFont.systemFont(ofSize: fontSize)
        }

        label.textColor = UIColor(hex: block.color ?? "#000000")

        if block.underscore == true {
            let attributed = NSAttributedString(
                string: label.text ?? "",
                attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue]
            )
            label.attributedText = attributed
        }

        stackView.addArrangedSubview(label)
    }
    
    private func applyButtonGroupBlock(_ group: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock) {
        guard let buttonGroupBlock = blocks.order?.first(where: {
            if case .buttonGroup = $0 { return true } else { return false }
        }), case .buttonGroup(let group) = buttonGroupBlock,
              let buttons = group.buttons else {
            return
        }
        
        let type = group.buttonGroupType?
            .replacingOccurrences(of: "InAppButtonGroupType.", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        switch type {

        case "singlevertical":
            if let button = buttons.first {
                let buttonView = createButton(from: button)
                stackView.addArrangedSubview(buttonView)
            }

        case "doublevertical":
            for buttonData in buttons {
                let buttonView = createButton(from: buttonData)
                stackView.addArrangedSubview(buttonView)
            }

        case "doublecompactvertical":
            for i in stride(from: 0, to: buttons.count, by: 2) {
                let hStack = UIStackView()
                hStack.axis = .horizontal
                hStack.spacing = 8
                hStack.distribution = .fillEqually
                hStack.translatesAutoresizingMaskIntoConstraints = false

                if i < buttons.count {
                    let btn1 = createButton(from: buttons[i])
                    hStack.addArrangedSubview(btn1)
                }
                if i + 1 < buttons.count {
                    let btn2 = createButton(from: buttons[i + 1])
                    hStack.addArrangedSubview(btn2)
                }

                stackView.addArrangedSubview(hStack)
            }

        case "singlecompactvertical":
            if let button = buttons.first {
                let buttonView = createButton(from: button)
                let wrapper = UIView()
                wrapper.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(buttonView)
                buttonView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    buttonView.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                    buttonView.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    buttonView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
                ])
                stackView.addArrangedSubview(wrapper)
            }

        case "singlecentered":
            if let button = buttons.first {
                let buttonView = createButton(from: button)
                buttonView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    buttonView.widthAnchor.constraint(equalToConstant: 220),
                    buttonView.heightAnchor.constraint(equalToConstant: 48)
                ])
                let wrapper = UIView()
                wrapper.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(buttonView)
                NSLayoutConstraint.activate([
                    buttonView.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                    buttonView.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    buttonView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
                ])
                stackView.addArrangedSubview(wrapper)
            }

        case "doublestacked":
            for buttonData in buttons.prefix(2) {
                let buttonView = createButton(from: buttonData)
                buttonView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    buttonView.heightAnchor.constraint(equalToConstant: 36)
                ])
                stackView.addArrangedSubview(buttonView)
            }
        default:
            // Fallback: Tek geniş dikey buton
            if let button = buttons.first {
                let buttonView = createButton(from: button)
                stackView.addArrangedSubview(buttonView)
            }
        }
    }
    private func handleAction(_ action: String?) {
        guard let action = action?.trimmingCharacters(in: .whitespacesAndNewlines),
              !action.isEmpty else {
            return
        }

        if action.lowercased() == "dismiss" {
            self.dismiss(animated: true)
        } else if action.lowercased().starts(with: "copy:") {
            let textToCopy = action.replacingOccurrences(of: "copy:", with: "").trimmingCharacters(in: .whitespaces)
            UIPasteboard.general.string = textToCopy
            print("📋 Kopyalandı: \(textToCopy)")
        } else if action.lowercased().starts(with: "http") {
            if let url = URL(string: action) {
                UIApplication.shared.open(url)
            }
        } else if action.lowercased().starts(with: "myapp://") {
            if let url = URL(string: action) {
                UIApplication.shared.open(url)
            }
        } else {
            print("⚠️ Desteklenmeyen action geldi: \(action)")
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyTransition() // veya kendi giriş animasyon fonksiyonun
    }
    
}
