//
//  StyleViewController.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 20.02.2025.
//

import UIKit

class StyleViewController: UIViewController {

    private let style: CustomInAppPayload.Layout.Style
    
    private let close: CustomInAppPayload.Layout.Close
    
    private let extra: CustomInAppPayload.Layout.Extra
    
    private let blocks: CustomInAppPayload.Layout.Blocks

    private let containerView = UIView()
    
    private var containerHeightConstraint: NSLayoutConstraint?
    
    private let overlayView = UIView()
    
    private let arrowImageView = UIImageView()
    
    private let closeButton = UIButton(type: .system)
    
    private let defaultLang: String
    
    private let stackView: UIStackView = {
            let stackView = UIStackView()
            stackView.axis = .vertical
        stackView.alignment = .fill
            stackView.distribution = .equalSpacing
            stackView.spacing = 12
            stackView.translatesAutoresizingMaskIntoConstraints = false
            return stackView
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
        
        setupUI()
        
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

    }
  
    override func viewWillAppear(_ animated: Bool) {
        applyTransition()
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
        
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(containerView)
        
        //let centerYConstraint = containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        
        
        //centerYConstraint.identifier = "containerCenterY"
        
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.contentMode = .scaleAspectFill
        arrowImageView.isHidden = true
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isHidden = true
        //view.addSubview(closeButton)
        
        containerView.insertSubview(closeButton, at: 0)
        
        containerView.insertSubview(arrowImageView, at: 0)
        
        containerView.insertSubview(stackView, at: 1)
        
        //view.addSubview(arrowImageView)
 
        NSLayoutConstraint.activate([
            
            //containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            //containerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            //centerYConstraint,
   
            arrowImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            arrowImageView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 8),
            arrowImageView.widthAnchor.constraint(equalToConstant: 32),
            arrowImageView.heightAnchor.constraint(equalToConstant: 32),
            //arrowImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            //closeButton.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -8)
        ])
        

        applyStyle()
        
        
        
        /*NSLayoutConstraint.activate([
           
        ])*/
        
        
        applyClose()
        applyOverlay()
        applyBlocks()
        
    }
 
   private func applyStyle() {
        
        if style.navigationalArrows ?? true{
            
            arrowImageView.image = UIImage(systemName: "arrow.left.square.fill")
            arrowImageView.tintColor = .blue
            arrowImageView.isHidden = false
            
        }
        
       if let bgColorHex = style.bgColor {
            
            containerView.backgroundColor = UIColor(hex: bgColorHex)
 
        }
 
       let radius = style.radius
       
       let radiusValue = CGFloat(radius ?? 0)
       
       containerView.layer.cornerRadius = radiusValue
       
       containerView.clipsToBounds = true
        
       if let bgImageStr = style.bgImage, !bgImageStr.isEmpty {
            addBackgroundImage(urlString: bgImageStr)
        }
        
        if style.verticalPosition == "bottom" {
            
            //containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 450).isActive = true
            
            containerView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ).isActive = true
     
        } else if style.verticalPosition == "center" {
            
            //containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 275).isActive = true
            
            //containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -275).isActive = true
            
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
            
            
        } else if style.verticalPosition == "top" {
            
            //containerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
            
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20).isActive = true
        }
 
    }
    
    private func applyClose() {
        
        if close.active ?? true {
            
            closeButton.isHidden = false
        } else {
            
            closeButton.isHidden = true
        }
        
        if let position = close.position {
            
            switch position {
                
            case "left":
                
                NSLayoutConstraint.activate([
                            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
                            closeButton.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 8)
                        ])
            case "right":
                
                NSLayoutConstraint.activate([
                           closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
                           closeButton.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -8)
                       ])
                
            case "outside-left":
                
                NSLayoutConstraint.activate([
                           closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -28),
                           // containerView’dan soldan -8 px (ya da -16) offset
                           closeButton.rightAnchor.constraint(equalTo: containerView.leftAnchor, constant: 12)
                       ])
                
            case "outside-right":
                
                NSLayoutConstraint.activate([
                         closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -28),
                         // containerView’dan sağdan +8 px offset
                         closeButton.leftAnchor.constraint(equalTo: containerView.rightAnchor, constant: -12)
                     ])
                     
                 default:
                     break
                
            }
            
               }
        
        if let type = close.type {
                   switch type {
                   case "icon":
                       // icon: color, style (“outlined”, “filled”, “basic”)
                       applyCloseIcon(close.icon)
                       
                   case "text":
                       // text: label, fontSize, color
                       applyCloseText(close.text)
                       
                   default:
                       break
                   }
               }
        
    }
    
    private func applyCloseIcon(_ icon: CustomInAppPayload.Layout.Close.Icon?) {
        
        closeButton.setTitle(nil, for: .normal)
               
               
               var systemImageName = "xmark"  // basic
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
    
    private func applyCloseText(_ textData: CustomInAppPayload.Layout.Close.CloseText?) {
        
        closeButton.setImage(nil, for: .normal)
        
        let lang = defaultLang
        
        var title = close.text?.label![lang]
               if let dict = textData?.label {
                   title = dict[lang] ?? dict["en"] ?? "Close"
               }
               
               closeButton.setTitle(title, for: .normal)
        
        if let colorHex = textData?.color, let color = UIColor(hex: colorHex) {
                    closeButton.setTitleColor(color, for: .normal)
                }
                
                if let fontSizeStr = textData?.fontSize{
                    
                    let filteredFontSize = fontSizeStr.filter { char in
                        
                        return char.isNumber || char == "."
                    }
                    
                    let fontSizeFloat = Float(filteredFontSize) ?? 0
                    
                    let fontSizeVal = CGFloat(fontSizeFloat)
                    
                    closeButton.titleLabel?.font = UIFont.systemFont(ofSize: fontSizeVal)
                }
        
    }
    
    private func addBackgroundImage(urlString: String) {
        let bgImageView = UIImageView()
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true
        
        containerView.insertSubview(bgImageView, at: 0)
        
        //view.addSubview(bgImageView)
        
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            //bgImageView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        if let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        bgImageView.image = image
                        
                        let aspectRatio = image.size.height / image.size.width
                        bgImageView.heightAnchor.constraint(equalTo: bgImageView.widthAnchor, multiplier: aspectRatio).isActive = true
                        
                    }
                }
            }.resume()
        }
        
        if let image = bgImageView.image {
            let aspectRatio = image.size.height / image.size.width
            bgImageView.heightAnchor.constraint(equalTo: bgImageView.widthAnchor, multiplier: aspectRatio).isActive = true
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
        
        if let overlayColorHex = (extra.overlay?.color){
            
            let color = UIColor(hex: overlayColorHex)
            
            overlayView.backgroundColor = color?.withAlphaComponent(0.1)
            
        }
     }
    
    private func applyTransition() {
        guard let transitionType = extra.transition else {
            return
        }
        
        switch transitionType {  //çalışıyor ama düzgün değil.
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
    
    private func applyBlocks() {
        
        let align = blocks.align
        
        let language = defaultLang
        
        
        //let text = tt.label?[language]
        
        guard let blockItems = blocks.order else { return }

        for block in blockItems {
            if case .buttonGroup(let buttonGroupBlock) = block {
                 
                guard let buttonGroupType = buttonGroupBlock.buttonGroupType else { continue }
                
                guard let buttons = buttonGroupBlock.buttons else { continue }
                
               
                switch buttonGroupType {
                case "single-vertical":
                    if let first = buttons.first{
                        let firstButton = addButton(first)
                        //let f = addButton(first)
                        //let g = addButton(first)
                    }
                case "double-vertical":
                    if let first = buttons.first,
                       let last = buttons.last{
                        let firstButton = addButton(first)
                        let lastButton = addButton(last)
                    }
                    
                default:
                    return
                }

            }
            
            else if case .text(let textBlock) = block {
                
                 let text = textBlock
                
                //addText(textBlock: text)
                //addText(textBlock: text)
                //addText(textBlock: text)
           
            }
            
            else if case .image(let imageBlock) = block {
                
                let image = imageBlock
                
                //addImage(imageBlock: image)
            }
        }

        
        
       
        
        /*let btn = UIButton(type: .system)
            //bbtn.setTitle(text, for: .normal)
            btn.backgroundColor = .systemGreen
            btn.setTitleColor(.white, for: .normal)
            btn.layer.cornerRadius = 12
            btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.insertSubview(btn, at: 1)
        
        if align == "top" {
            
            NSLayoutConstraint.activate([
                //btn.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                //btn.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: <#T##CGFloat#>)
                
                btn.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
                btn.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                
                btn.widthAnchor.constraint(equalToConstant: 100),
                btn.heightAnchor.constraint(equalToConstant: 40)

            ])
        }*/
        
       
            
       /*guard let orderArray = blocks.order else { return }
        
        for block in orderArray {
            switch block {
            case .spacer(let spacerBlock):
                applySpacerBlock(spacerBlock)
            default:
                break
            }
        }*/
        
        
        
    }
    
    /*private func applySpacerBlock(_ spacer: CustomInAppPayload.Layout.Blocks.SpacerBlock) {
        let fill = spacer.fillAvailableSpacing ?? false
        
        let verticalSpacing = spacer.verticalSpacing ?? ""
        
        let verticalSpacingFilter = verticalSpacing.filter { char in
            
            return char.isNumber || char == "."
        }
        
        let verticalSpacingInt = Int(verticalSpacingFilter)
        
        let spacing = verticalSpacingInt ?? 0
        
        if fill {
            
            if let ch = containerHeightConstraint {
                ch.constant += CGFloat(spacing)
            }
        } else {
            
        }
    }*/
    
    private func addImage(imageBlock: CustomInAppPayload.Layout.Blocks.ImageBlock) -> UIImageView {
        
        let image = UIImageView()
        
        let url = imageBlock.url ?? ""
        
        if let urlString = URL(string: url) {
            URLSession.shared.dataTask(with: urlString) { data, _, _ in
                if let data = data, let imagee = UIImage(data: data) {
                    DispatchQueue.main.async {
                        image.image = imagee
                        
                    }
                }
            }.resume()
        }
        
        let radius = imageBlock.radius
        
        image.layer.cornerRadius = CGFloat(radius ?? 0)
        
        let margin = imageBlock.margin
        
        image.translatesAutoresizingMaskIntoConstraints = false
        
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(image)
        
        stackView.addArrangedSubview(wrapper)
        
        
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: CGFloat(margin ?? 10)),
            image.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: CGFloat(-(margin ?? 10))),
            image.topAnchor.constraint(equalTo: wrapper.topAnchor),
            image.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            image.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        
        return image
    }
    
    private func addText(textBlock: CustomInAppPayload.Layout.Blocks.TextBlock) -> UILabel {
        
        let textLabel = UILabel()
        
        //let textContainerView = UIView()
        
//textContainerView.addSubview(textLabel)
        
        textLabel.numberOfLines = 0
        
        textLabel.lineBreakMode = .byWordWrapping
        
        let language = defaultLang
        
        textLabel.text = textBlock.content?[language] ?? "u"
        
        if let textColor = textBlock.color {
            
            textLabel.textColor = UIColor(hex: textColor)
        }
        
        let fontFamily = textBlock.fontFamily
        let fontSize = textBlock.fontSize
        let fontWeight = textBlock.fontWeight
        let italic = textBlock.italic
        let underscore = textBlock.underscore
        
        if let fontModel = FontModel(family: fontFamily, weight: fontWeight, size: fontSize, italic: italic, underline: underscore) {
            
            textLabel.attributedText = fontModel.attributedString(textLabel.text ?? "")
        }
        
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let horizontalMargin = textBlock.horizontalMargin ?? 0
        
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(textLabel)
        
        //stackView.addArrangedSubview(textLabel)
        
        switch textBlock.textAlignment{
        case "left":
            //textLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: CGFloat(10 + horizontalMargin)).isActive = true
            //textLabel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 0).isActive = true
            textLabel.textAlignment = .left
            textLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: CGFloat(10 + horizontalMargin)).isActive = true
            textLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
            textLabel.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 5).isActive = true
            textLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
            
        case "center":
            //textLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 100).isActive = true
            //textLabel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 0).isActive = true
            textLabel.textAlignment = .center
            textLabel.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 5).isActive = true
            textLabel.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor).isActive = true
            
            
        case "right":
            //textLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: CGFloat(250 - horizontalMargin)).isActive = true
            //textLabel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 0).isActive = true
            textLabel.textAlignment = .right
            textLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
            textLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
            textLabel.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 5).isActive = true
            //textLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
            
        default:
            textLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 100).isActive = true
            textLabel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 0).isActive = true
            
        }
 
        //containerView.insertSubview(textLabel, at: 2)
        
        stackView.addArrangedSubview(wrapper)

        return textLabel
        
    }
    
    
    private func addButton(_ buttonBlock: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock) -> UIButton {
        let button = UIButton(type: .system)
     
        let lang = defaultLang
        let title = buttonBlock.label?[lang] ?? "Unnamed"
        
        button.setTitle(title, for: .normal)
        
        let fontFamily = buttonBlock.fontFamily
        let fontWeight = buttonBlock.fontWeight
        let fontSize = buttonBlock.fontSize
        let italic = buttonBlock.italic
        let underscore = buttonBlock.underscore
        
        if let fontModel = FontModel(family: fontFamily, weight: fontWeight, size: fontSize, italic: italic, underline: underscore) {
            
            let attrTitle = fontModel.attributedString(title)
            button.setAttributedTitle(attrTitle, for: .normal)
        }
        
        if let hexText = buttonBlock.textColor,
              let colorText = UIColor(hex: hexText) {
               button.setTitleColor(colorText, for: .normal)
           } else {
               
               button.setTitleColor(.link, for: .normal)
           }
        
        if let hexBackground = buttonBlock.backgroundColor,
           let colorBackground = UIColor(hex: hexBackground){
            button.backgroundColor = colorBackground
        }else {
            button.backgroundColor = .link
            
            
        }
        
        if let hexBorder = buttonBlock.borderColor,
              let colorBorder = UIColor(hex: hexBorder) {
              button.layer.borderColor = colorBorder.cgColor
              button.layer.borderWidth = 1.0
           }
        
        if let cornerRadius = buttonBlock.borderRadius {
            
            let cgFloatCornerRadius = CGFloat(cornerRadius)
            
            button.layer.cornerRadius = cgFloatCornerRadius
            
        }
        
        let marginInt = buttonBlock.margin ?? 16    // varsayılan 16
        let margin = CGFloat(marginInt)
        
        let wrapper = UIView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(button)
  
        let height: CGFloat = {
             switch buttonBlock.verticalSize?.lowercased() {
             case "small":
                 return 40
             case "medium":
                 return 60
             case "large":
                 return 80
             default:
                 return 40
             }
         }()
        
        let horizontalSize = buttonBlock.horizontalSize
        
        let buttonPosition = buttonBlock.buttonPosition
        
        //stackView.addArrangedSubview(button)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        //containerView.insertSubview(button, at: 2)
        
        if horizontalSize == "large" {
               // large: margin’a göre full-width
               NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: margin),
                button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -margin),
                button.topAnchor.constraint(equalTo: wrapper.topAnchor),
                button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                button.heightAnchor.constraint(equalToConstant: height)
               ])
        } else {
            
            
                switch horizontalSize {
                       case "small":
                    
                    switch buttonPosition {
                    case "centered":
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -125).isActive = true
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 125).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 5).isActive = true
                        //button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "left":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -240).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "right":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 240).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    default:
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 100).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -100).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    }
                    //button.widthAnchor.constraint(equalToConstant: 100).isActive = true
                       case "medium":
                       
                    switch buttonPosition {
                    case "centered":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 100).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -100).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "left":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -200).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "right":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 200).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                        
                    default:
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    }
                    
                   // button.widthAnchor.constraint(equalToConstant: 150).isActive = true
                    
                       default:
                    switch buttonPosition {
                    case "centered":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "left":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "right":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    default:
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    }
                    
                   // button.widthAnchor.constraint(equalToConstant: 150).isActive = true
                       }
                
        }
        
        stackView.addArrangedSubview(wrapper)
        
        return button
       
        
        
    }


    
    @objc private func didTapClose() {
        guard let transitionType = extra.transition else {
            dismiss(animated: true)
            return
        }
        
        UIView.animate(withDuration: 0.1, animations: {
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
