//
//  BannerViewController.swift
//  Paylisher
//
//  Created by elif uyar on 9.07.2025.
//

import UIKit

class BannerViewController: UIViewController{
    private let style: CustomInAppPayload.Layout.Style
    private let close: CustomInAppPayload.Layout.Close
    private let extra: CustomInAppPayload.Layout.Extra
    private let blocks: CustomInAppPayload.Layout.Blocks
    private let containerView = UIView()
    private let closeButton = UIButton(type: .system)
    private let defaultLang: String
    private let overlayView = UIView()
    
    private let bannerImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.isHidden = true// eğer image gelmezse gizli kalır
        return imageView
    }()
    
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
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupUI()
        applyCloseIcon(close.icon)
        applyStyle()
        applyClose()
        setupBannerImageIfNeeded()
        setupTextBlockIfNeeded()
        setupBannerActionIfNeeded()
        setupCloseAction()
    }

    private func setupUI() {
        view.backgroundColor = .clear
    
        containerView.layer.cornerRadius = CGFloat(style.radius ?? 12)
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 80)
        ])
       
        containerView.addSubview(bannerImageView)
        NSLayoutConstraint.activate([
            bannerImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            bannerImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            bannerImageView.widthAnchor.constraint(equalToConstant: 56),
            bannerImageView.heightAnchor.constraint(equalToConstant: 56)
        ])
    
        containerView.addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
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
    private func applyStyle() {
        // Sadece vertical pozisyonu(top veya bottom)
        if let bgColorHex = style.bgColor, let bgColor = UIColor(hex: bgColorHex) {
            containerView.backgroundColor = bgColor
        } else {
            containerView.backgroundColor = .white
        }

        if style.verticalPosition == "bottom" {
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        } else {
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12).isActive = true
        }
    }
    private func applyClose() {
        if !(close.active ?? true) {
            closeButton.isHidden = true
            return
        }
        closeButton.isHidden = false
        closeButton.removeFromSuperview()
        containerView.addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        var constraints: [NSLayoutConstraint] = [
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24)
        ]

        if close.position == "left" {
            constraints.append(closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8))
        } else {
            constraints.append(closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8))
        }

        NSLayoutConstraint.activate(constraints)
    }
    
    private func setupTextBlockIfNeeded() {
        guard let textBlockItem = blocks.order?.first(where: {
            if case .text = $0 { return true } else { return false }
        }), case .text(let block) = textBlockItem else {
            return
        }

        let textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.numberOfLines = 0
        
        let contentDict = block.content ?? [:]
        let content = contentDict[defaultLang] ?? contentDict["en"] ?? "No content"

        if let hexColor = block.color {
            textLabel.textColor = UIColor(hex: hexColor)
        }
        switch block.textAlignment {
        case "left":
            textLabel.textAlignment = .left
        case "right":
            textLabel.textAlignment = .right
        default:
            textLabel.textAlignment = .center
        }

        let fontSizeValue = Double(block.fontSize?.replacingOccurrences(of: "px", with: "") ?? "") ?? 16
        let fontSize = CGFloat(fontSizeValue)

        var font: UIFont?

        let fontFamily = (block.fontFamily ?? "").lowercased()

        if fontFamily.contains("helvetica") {
            if block.fontWeight == "bold" && block.italic == true {
                font = UIFont(name: "Helvetica-BoldOblique", size: fontSize)
            } else if block.fontWeight == "bold" {
                font = UIFont(name: "Helvetica-Bold", size: fontSize)
            } else if block.italic == true {
                font = UIFont(name: "Helvetica-Oblique", size: fontSize)
            } else {
                font = UIFont(name: "Helvetica", size: fontSize)
            }
        } else {
            font = UIFont.systemFont(ofSize: fontSize)
            if block.fontWeight == "bold" && block.italic == true {
                font = UIFont(descriptor: font!.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) ?? font!.fontDescriptor, size: fontSize)
            } else if block.fontWeight == "bold" {
                font = UIFont.boldSystemFont(ofSize: fontSize)
            } else if block.italic == true {
                font = UIFont.italicSystemFont(ofSize: fontSize)
            }
        }
        
        if block.underscore == true {
            let attributed = NSAttributedString(string: content, attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: font as Any
            ])
            textLabel.attributedText = attributed
        } else {
            textLabel.font = font
            textLabel.text = content
        }

        containerView.addSubview(textLabel)

        NSLayoutConstraint.activate([
            textLabel.leadingAnchor.constraint(equalTo: bannerImageView.trailingAnchor, constant: CGFloat(block.horizontalMargin ?? 8)),
            textLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            textLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    @objc private func closeButtonTapped() {
        self.dismiss(animated: true)
    }
    
    private func setupBannerImageIfNeeded() {
        guard let imageBlock = blocks.order?.first(where: {
            if case .image = $0 { return true } else { return false }
        }), case .image(let block) = imageBlock,
              let imageUrl = block.url else {
            return
        }
        loadImage(from: imageUrl)
        bannerImageView.isHidden = false
    }
    
    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.bannerImageView.image = image
                    self.bannerImageView.isHidden = false //gösteriyor
                }
            }
        }.resume()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        containerView.transform = CGAffineTransform(translationX: 0, y: -100)
        UIView.animate(withDuration: 0.25) {
            self.containerView.transform = .identity
        }
        
        if let duration = extra.banner?.duration, duration > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) {
                self.dismiss(animated: true)
            }
        }
    }
    
    private func setupBannerActionIfNeeded() {
        if let action = extra.banner?.action, !action.isEmpty {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBannerAction))
            containerView.isUserInteractionEnabled = true
            containerView.addGestureRecognizer(tapGesture)
        }
    }
    
    @objc private func handleBannerAction() {
        guard let action = extra.banner?.action,
              let url = URL(string: action),
              UIApplication.shared.canOpenURL(url) else {
            return
        }

        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        
        // Opsiyonel: banner’ı da kapat
        self.dismiss(animated: true)
    }
    
    private func setupCloseAction() {
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
    }
   
}
