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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(containerView)
        
        let centerYConstraint = containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        
        centerYConstraint.identifier = "containerCenterY"
        
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.isHidden = true
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isHidden = true
        view.addSubview(closeButton)
        
        containerView.addSubview(arrowImageView)
        
        
        
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerYConstraint,
            containerView.widthAnchor.constraint(equalToConstant: 350),
            containerView.heightAnchor.constraint(equalToConstant: 250),
            arrowImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            arrowImageView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 8),
            arrowImageView.widthAnchor.constraint(equalToConstant: 32),
            arrowImageView.heightAnchor.constraint(equalToConstant: 32),
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            //closeButton.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -8)
        ])
        
        applyStyle(centerYConstraint: centerYConstraint)
        applyClose()
        applyOverlay()
        
        
    }
    
   
    
   private func applyStyle(centerYConstraint: NSLayoutConstraint) {
        
        if style.navigationalArrows ?? true{
            
            arrowImageView.image = UIImage(systemName: "arrow.left.square.fill")
            arrowImageView.tintColor = .blue
            arrowImageView.isHidden = false
            
        }
        
       if let bgColorHex = style.bgColor {
            
            containerView.backgroundColor = UIColor(hex: bgColorHex)
 
        }
       
       
        
       let radius = style.radius
       
       let radiusValue = CGFloat(radius!)
       
       containerView.layer.cornerRadius = radiusValue
       
       containerView.clipsToBounds = true
        
        if let bgImageStr = style.bgImage, !bgImageStr.isEmpty {
            addBackgroundImage(urlString: bgImageStr)
        }
        
        if style.verticalPosition == "bottom" {
            
            centerYConstraint.isActive = false
            
            containerView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ).isActive = true
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
        
        let overlayColorHex = (extra.overlay?.color)!
            
        let color = UIColor(hex: overlayColorHex)
            
        overlayView.backgroundColor = color?.withAlphaComponent(0.5)
        
         
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
    
   /* private func applyBlocks() {
    
        guard let orderArray = blocks.order else { return }
        
        for block in orderArray {
            switch block {
            case .spacer(let spacerBlock):
                applySpacerBlock(spacerBlock)
            default:
                break
            }
        }
    }*/
    
    /*private func applySpacerBlock(_ spacer: CustomInAppPayload.Layout.Blocks.SpacerBlock) {
        let fill = spacer.fillAvailableSpacing ?? false
        let spacing = spacer.verticalSpacing ?? 0
        
        if fill {
            
            if let ch = containerHeightConstraint {
                ch.constant += CGFloat(spacing)
            }
        } else {
            
        }
    }*/

    
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
