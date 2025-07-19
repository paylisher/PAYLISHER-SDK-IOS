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
    
    private let layout: CustomInAppPayload.Layout

    private let containerView = UIView()
    
    private var containerHeightConstraint: NSLayoutConstraint?
    
    private let overlayView = UIView()
    
    //private let arrowImageView = UIImageView()
    
    private var bgAspectConstraint: NSLayoutConstraint?
    
    private let closeButton = UIButton(type: .system)
    
    private let defaultLang: String
    
    private let mainStackView: UIStackView = {
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.alignment = .fill
        stackView.distribution = .equalSpacing
            stackView.isLayoutMarginsRelativeArrangement = true
            stackView.layoutMargins = .init(top: 0, left: 0, bottom: 0, right: 0)
            stackView.spacing = 10
            stackView.translatesAutoresizingMaskIntoConstraints = false
            return stackView
        }()
    
    init(style: CustomInAppPayload.Layout.Style,
         close: CustomInAppPayload.Layout.Close,
         extra: CustomInAppPayload.Layout.Extra,
         blocks: CustomInAppPayload.Layout.Blocks,
         defaultLang: String,
         layout: CustomInAppPayload.Layout) {
        self.style = style
        self.close = close
        self.extra = extra
        self.blocks = blocks
        self.defaultLang = defaultLang
        self.layout = layout
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

    }
    
    override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            // stackView’e en az bir alt eleman eklendiyse
            if !mainStackView.arrangedSubviews.isEmpty {
                bgAspectConstraint?.priority = .defaultHigh   // 750
            }
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
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isHidden = true
        
        containerView.insertSubview(mainStackView, at: 1)
        
        containerView.addSubview(closeButton)
 
        NSLayoutConstraint.activate([

            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            
            mainStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            {
                let constraint = mainStackView.bottomAnchor.constraint(
                           lessThanOrEqualTo: containerView.bottomAnchor)
                constraint.priority = .defaultHigh // 750
                return constraint
               }()
        ])
        applyStyle()
        applyClose()
        applyOverlay()
        applyBlocks()
    }
 
   private func applyStyle() {
        
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
        
       else{
           containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
       }
       
        if style.verticalPosition == "bottom" {
            
            containerView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ).isActive = true
     
        } else if style.verticalPosition == "center" {
            
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
            
            
        } else if style.verticalPosition == "top" {
            
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
                     
                       applyCloseIcon(close.icon)
                       
                   case "text":
                     
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

        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

        ])
        
        if let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        bgImageView.image = image
                      
                        let ratio = image.size.height / image.size.width

                                        
                        self.bgAspectConstraint?.isActive = false
                                            
                        let constraint = bgImageView.heightAnchor.constraint(equalTo: bgImageView.widthAnchor,multiplier: ratio)

                        constraint.priority = self.mainStackView.arrangedSubviews.isEmpty ? .required : .defaultHigh  // 750
                        constraint.isActive = true
                        self.bgAspectConstraint = constraint
  
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

        guard let unsortedBlocks = blocks.order else { return }

        let sortedBlocks = unsortedBlocks.sorted(by: { $0.orderValue < $1.orderValue })

            for block in sortedBlocks {

                switch block {

                case .buttonGroup(let buttonGroupBlock):
                    guard let buttonGroupType = buttonGroupBlock.buttonGroupType else { continue }
                    
                    guard let buttons = buttonGroupBlock.buttons else { continue }
      
                    switch buttonGroupType {
                    case "single-vertical":
                        if let first = buttons.first{
                           let firstButton = addButtonVertical(first)
                           //let f = addButtonVertical(first)
                            //let g = addButtonVertical(first)
                            //let d = addButtonVertical(first)
                            //let c = addButtonVertical(first)
                           // let v = addButtonVertical(first)
                           
                            break
                            
                        }
                    case "double-vertical":
                        if let first = buttons.first,
                           let last = buttons.last{
                            let firstButton = addButtonVertical(first)
                            let lastButton = addButtonVertical(last)
                            break
                        }
                    case "double-horizontal":
                        if let first = buttons.first,
                            let last = buttons.last{
                           
                            let firstButton = addButtonHorizontal(firstButtonBlock: first, secondButtonBlock: last)
                            //let lastButton = addButtonHorizontal(firstButtonBlock: first, secondButtonBlock: last)
                            break
                        }
                    case "single-compact-vertical":
                        if let first = buttons.first{
                            let firstButton = addButtonVertical(first)
                            break
                        }
                    case "double-compact-vertical":
                        if let first = buttons.first,
                           let last = buttons.last{
                            let firstButton = addButtonVertical(first)
                            let lastButton = addButtonVertical(last)
                            break
                        }
                        
                    default:
                        return
                    }

                case .spacer(let spacerBlock):
                    _ = addSpacer(spacerBlock: spacerBlock)
                    break

                case .text(let textBlock):
                    _ = addText(textBlock: textBlock)
                   // _ = addText(textBlock: textBlock)
                   // _ = addText(textBlock: textBlock)
                    break

                case .image(let imageBlock):
                    _ = addImage(imageBlock: imageBlock)
                    break
                }
            }
       
    }
    
    private func addImage(imageBlock: CustomInAppPayload.Layout.Blocks.ImageBlock) -> UIImageView {
        
        let image = UIImageView()
        
        let url = imageBlock.url ?? ""
        
        if let urlString = URL(string: url) {
            URLSession.shared.dataTask(with: urlString) { data, _, _ in
                if let data = data, let imagee = UIImage(data: data) {
                    DispatchQueue.main.async {
                        image.image = imagee
                        
                        let ratio = imagee.size.height / imagee.size.width
                        image.heightAnchor.constraint(equalTo: image.widthAnchor, multiplier: ratio).isActive = true
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
        mainStackView.addArrangedSubview(wrapper)
        wrapper.addSubview(image)

        
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: CGFloat(margin ?? 0)),
            image.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: CGFloat(-(margin ?? 0))),
            image.topAnchor.constraint(equalTo: wrapper.topAnchor),
            image.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            
         
        ])
        
        
        return image
    }
    
    private func addSpacer(spacerBlock: CustomInAppPayload.Layout.Blocks.SpacerBlock) -> UIView {
        let spacer = UIView()
        
        let verticalSpacingStr = spacerBlock.verticalSpacing
        
        let filteredVerticalSpacing = (verticalSpacingStr?.filter { char in
            
            return char.isNumber || char == "."
        }) ?? ""
        
        let verticalSpacing = Double(filteredVerticalSpacing) ?? 0
        
        let fillAvailableSpacing = spacerBlock.fillAvailableSpacing
        
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        
        mainStackView.addArrangedSubview(wrapper)
        
        wrapper.addSubview(spacer)
        
        spacer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            spacer.topAnchor.constraint(equalTo: wrapper.topAnchor),
            spacer.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            spacer.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            spacer.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            
        ])
        
        if fillAvailableSpacing == true {
            spacer.heightAnchor.constraint(equalToConstant: 0).isActive = true
        }else{
            spacer.heightAnchor.constraint(equalToConstant: verticalSpacing).isActive = true
        }
        
        return spacer
    }
    
    private func addText(textBlock: CustomInAppPayload.Layout.Blocks.TextBlock) -> UILabel {
        
        let textLabel = UILabel()
        
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
        
        mainStackView.addArrangedSubview(wrapper)
        wrapper.addSubview(textLabel)
        
        
        switch textBlock.textAlignment{
        case "left":
            textLabel.textAlignment = .left
            textLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: CGFloat(10 + horizontalMargin)).isActive = true
            textLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor).isActive = true
            textLabel.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10).isActive = true
            textLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
            
        case "center":

            textLabel.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor).isActive = true
            textLabel.textAlignment = .center
            textLabel.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10).isActive = true
            textLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
            
            
        case "right":

            textLabel.textAlignment = .right
            textLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: CGFloat(-10-horizontalMargin)).isActive = true
            textLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor).isActive = true
            textLabel.topAnchor.constraint(equalTo: wrapper.topAnchor,constant: 10).isActive = true
            textLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
            
        default:
            textLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
            textLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: 0).isActive = true
            textLabel.topAnchor.constraint(equalTo: wrapper.topAnchor,constant: 10).isActive = true
            textLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
        }

        return textLabel
        
    }

    private func addButtonVertical(_ buttonBlock: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock) -> UIButton {
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
        mainStackView.addArrangedSubview(wrapper)
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

        button.translatesAutoresizingMaskIntoConstraints = false
        
        if horizontalSize == "large" {
               
               NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: margin),
                button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -margin),
                button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10),
                button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10),
                button.heightAnchor.constraint(equalToConstant: height)
                
               ])
        } else {

                switch horizontalSize {
                       case "small":
                    
                    switch buttonPosition {
                    case "centered":
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -100).isActive = true
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 100).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "left":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -200).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "right":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 200).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                       
                    default:
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 100).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -100).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
                    
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                        
                    }

                       case "medium":
                       
                    switch buttonPosition {
                    case "centered":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 75).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -75).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "left":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -150).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "right":
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 150).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                        
                    default:
                        button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10).isActive = true
                        button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10).isActive = true
                        button.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10).isActive = true
                        button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10).isActive = true

                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    }
                    
                       default:
                    switch buttonPosition {
                    case "centered":
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "left":

                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    case "right":
                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    default:

                        button.heightAnchor.constraint(equalToConstant: height).isActive = true
                    }

                       }
                
        }

        return button

    }
    
    private func addButtonHorizontal(firstButtonBlock: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock, secondButtonBlock: CustomInAppPayload.Layout.Blocks.ButtonGroupBlock.ButtonBlock) -> (first: UIButton, second: UIButton) {
        
        let firstButton = UIButton()
        let secondButton = UIButton()
     
        let lang = defaultLang
        let firstButtonTitle = firstButtonBlock.label?[lang] ?? "Unnamed"
        let secondButtonTitle = secondButtonBlock.label?[lang] ?? "Unnamed"
        
        firstButton.setTitle(firstButtonTitle, for: .normal)
        secondButton.setTitle(secondButtonTitle, for: .normal)
        
        let firstButtonFontFamily = firstButtonBlock.fontFamily
        let firstButtonFontWeight = firstButtonBlock.fontWeight
        let firstButtonFontSize = firstButtonBlock.fontSize
        let firstButtonItalic = firstButtonBlock.italic
        let firstButtonUnderscore = firstButtonBlock.underscore
        
        let secondButtonFontFamily = secondButtonBlock.fontFamily
        let secondButtonFontWeight = secondButtonBlock.fontWeight
        let secondButtonFontSize = secondButtonBlock.fontSize
        let secondButtonItalic = secondButtonBlock.italic
        let secondButtonUnderscore = secondButtonBlock.underscore
        
        if let firstFontModel = FontModel(family: firstButtonFontFamily  , weight: firstButtonFontWeight, size: firstButtonFontSize, italic: firstButtonItalic, underline: firstButtonUnderscore) {
            
            let firstAttrTitle = firstFontModel.attributedString(firstButtonTitle)
            firstButton.setAttributedTitle(firstAttrTitle, for: .normal)
        }
        
        if let secondFontModel = FontModel(family: secondButtonFontFamily  , weight: secondButtonFontWeight, size: secondButtonFontSize, italic: secondButtonItalic, underline: secondButtonUnderscore) {
            
            let secondAttrTitle = secondFontModel.attributedString(secondButtonTitle)
            secondButton.setAttributedTitle(secondAttrTitle, for: .normal)
        }
        
        
        if let firstHexText = firstButtonBlock.textColor,
              let colorText = UIColor(hex: firstHexText) {
               firstButton.setTitleColor(colorText, for: .normal)
           } else {
               
               firstButton.setTitleColor(.link, for: .normal)
           }
        
        if let secondHexText = secondButtonBlock.textColor,
              let colorText = UIColor(hex: secondHexText) {
               secondButton.setTitleColor(colorText, for: .normal)
           } else {
               
               secondButton.setTitleColor(.link, for: .normal)
           }
        
        
        if let firstHexBackground = firstButtonBlock.backgroundColor,
           let firstColorBackground = UIColor(hex: firstHexBackground){
            firstButton.backgroundColor = firstColorBackground
        }else {
            firstButton.backgroundColor = .link
  
        }
        
        if let secondHexBackground = secondButtonBlock.backgroundColor,
           let secondColorBackground = UIColor(hex: secondHexBackground){
            secondButton.backgroundColor = secondColorBackground
        }else {
            secondButton.backgroundColor = .link
  
        }
        
        if let firstHexBorder = firstButtonBlock.borderColor,
              let firstColorBorder = UIColor(hex: firstHexBorder) {
              firstButton.layer.borderColor = firstColorBorder.cgColor
              firstButton.layer.borderWidth = 1.0
           }
        
        if let secondHexBorder = secondButtonBlock.borderColor,
              let secondColorBorder = UIColor(hex: secondHexBorder) {
              secondButton.layer.borderColor = secondColorBorder.cgColor
              secondButton.layer.borderWidth = 1.0
           }

        
        if let firstCornerRadius = firstButtonBlock.borderRadius {
            
            let firstCgFloatCornerRadius = CGFloat(firstCornerRadius)
            
            firstButton.layer.cornerRadius = firstCgFloatCornerRadius
            
        }
        
        if let secondCornerRadius = secondButtonBlock.borderRadius {
            
            let secondCgFloatCornerRadius = CGFloat(secondCornerRadius)
            
            secondButton.layer.cornerRadius = secondCgFloatCornerRadius
            
        }
        
        let firstMarginInt = firstButtonBlock.margin ?? 16    // varsayılan 16
        let firstMargin = CGFloat(firstMarginInt)
        
        let secondMarginInt = secondButtonBlock.margin ?? 16    // varsayılan 16
        let secondMargin = CGFloat(secondMarginInt)
        
        let horizontalStack = UIStackView()
        
        let wrapper = UIView()
        
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        
        horizontalStack.axis = .horizontal
        
        horizontalStack.distribution = .fillProportionally
        
        horizontalStack.alignment = .leading
        
        horizontalStack.spacing = 8
        
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        
        mainStackView.addArrangedSubview(wrapper)

        wrapper.addSubview(horizontalStack)
        
        horizontalStack.addArrangedSubview(firstButton)
        horizontalStack.addArrangedSubview(secondButton)

        let firstHeight: CGFloat = {
             switch firstButtonBlock.verticalSize?.lowercased() {
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
        
        let firstHorizontalSize = firstButtonBlock.horizontalSize
        
        let firstButtonPosition = firstButtonBlock.buttonPosition

        let secondHeight: CGFloat = {
             switch secondButtonBlock.verticalSize?.lowercased() {
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
        
        let secondHorizontalSize = secondButtonBlock.horizontalSize
        
        let secondButtonPosition = secondButtonBlock.buttonPosition
        
        NSLayoutConstraint.activate([
  
            horizontalStack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10),
            horizontalStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10),
            horizontalStack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10),
            horizontalStack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -10),
         
         firstButton.heightAnchor.constraint(equalToConstant: firstHeight),
         secondButton.heightAnchor.constraint(equalToConstant: secondHeight),

        ])
        
        switch (firstHorizontalSize, secondHorizontalSize) {
        case ("large", "large"):
            horizontalStack.distribution = .fillEqually
        case ("large", "medium"):
            
            NSLayoutConstraint.activate([
                
                secondButton.widthAnchor.constraint(equalToConstant: 125)
            ])
        case ("large", "small"):
            
            NSLayoutConstraint.activate([
                secondButton.widthAnchor.constraint(equalToConstant: 100)
            ])
        case ("medium", "large"):
            
            NSLayoutConstraint.activate([
                firstButton.widthAnchor.constraint(equalToConstant: 125)
            ])
            
        case ("small", "large"):
            
            NSLayoutConstraint.activate([
                firstButton.widthAnchor.constraint(equalToConstant: 100)
            ])
        case ("small", "small"):
            
            horizontalStack.distribution = .equalSpacing
            NSLayoutConstraint.activate([
                firstButton.widthAnchor.constraint(equalToConstant: 100),
                secondButton.widthAnchor.constraint(equalToConstant: 100)
            ])
        case ("medium", "medium"):
            
            horizontalStack.distribution = .equalSpacing
            NSLayoutConstraint.activate([
                firstButton.widthAnchor.constraint(equalToConstant: 125),
                secondButton.widthAnchor.constraint(equalToConstant: 125)
            ])
            
        case ("medium", "small"):
            
            horizontalStack.distribution = .equalSpacing
            NSLayoutConstraint.activate([
                firstButton.widthAnchor.constraint(equalToConstant: 125),
                secondButton.widthAnchor.constraint(equalToConstant: 100)
            ])
            
        case ("small", "medium"):
            
            horizontalStack.distribution = .equalSpacing
            NSLayoutConstraint.activate([
                firstButton.widthAnchor.constraint(equalToConstant: 100),
                secondButton.widthAnchor.constraint(equalToConstant: 125)
            ])
            
        default:
            horizontalStack.distribution = .fillEqually
        }
        
        return (firstButton, secondButton)
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
