//
//  PaylisherCustomInAppNotificationManager.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 17.02.2025.
//

import Foundation
import UIKit

//@available(iOSApplicationExtension, unavailable)
public class PaylisherCustomInAppNotificationManager {
    
    public static let shared = PaylisherCustomInAppNotificationManager()
    
    
    
    private init() {
        
    }
    
   public func parseInAppPayload(from userInfo: [AnyHashable: Any], windowScene: UIWindowScene?) -> CustomInAppPayload? {
       
        guard let stringKeyedInfo = userInfo as? [String: Any] else {
            print("userInfo'yu [String:Any] olarak cast edemedim.")
            return nil
        }
        
        
        var normalizedInfo = [String: Any]()
        
        for (key, value) in stringKeyedInfo {
            
            if key == "layouts" {
            
                if let layoutsString = value as? String {
                    
                    if let data = layoutsString.data(using: .utf8) {
                        do {
                          
                            if let arrayObject = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                                normalizedInfo[key] = arrayObject
                            } else {
                                
                                print("layouts string, fakat array'e parse edilemedi")
                                
                                normalizedInfo[key] = value
                            }
                        } catch {
                            print("layouts'u parse ederken hata:", error)
                            normalizedInfo[key] = value
                        }
                    } else {
                        
                        normalizedInfo[key] = value
                    }
                }
                
                else {
                    normalizedInfo[key] = value
                }
            } else {
                
                normalizedInfo[key] = value
            }
        }
        
        
        do {
            let data = try JSONSerialization.data(withJSONObject: normalizedInfo, options: [])
            
            let decoder = JSONDecoder()
            let payload = try decoder.decode(CustomInAppPayload.self, from: data)
            return payload
        } catch {
            print("InAppPayload decode error:", error)
            return nil
        }
    }

    public func customInAppFunction(userInfo: [AnyHashable: Any], windowScene: UIWindowScene?) {
        
        guard let payload = parseInAppPayload(from: userInfo, windowScene: windowScene) else {
            print("Payload parse edilemedi.")
            return
        }
        let layoutType = payload.layoutType?.lowercased() ?? "modal"
       
        let lang = payload.defaultLang ?? "en"
      //  let layoutType = payload.layoutType ?? "no-type"
       // print("Default Lang:", lang)
       // print("Layout Type:", layoutType)
        
        
        if let layouts = payload.layouts, !layouts.isEmpty {
            let firstLayout = layouts[0]
    
            print("--------------Style---------------")
            
            if let style = firstLayout.style, let close = firstLayout.close, let extra = firstLayout.extra, let blocks = firstLayout.blocks{
                print("navigationalArrows: ", style.navigationalArrows ?? "")
                print("radius: ", style.radius ?? "")
                print("bgColor: ", style.bgColor ?? "")
                print("bgImage: ", style.bgImage ?? "")
                print("bgImageMask: ", style.bgImageMask ?? "")
                print("bgImageColor: ", style.bgImageColor ?? "")
                print("verticalPosition: ", style.verticalPosition ?? "")
                print("horizontalPosition: ", style.horizontalPosition ?? "boş")
                print("active: ", close.active ?? "")
                
                let styleVC = StyleViewController(style: style, close: close, extra: extra, blocks: blocks, defaultLang: lang)
                let bannerVC = BannerViewController(style:style,close:close,extra:extra,blocks:blocks,defaultLang:lang)
                let fullModalVC=fullScreenModalViewController(style: style, close: close, extra: extra, blocks: blocks, defaultLang: lang)
                //let modalVc=ModalViewController()
                
//#if IOS
//                styleVC.modalPresentationStyle = .overFullScreen
                        
//                if let rootVC = UIApplication.shared.windows.first?.rootViewController {
//                    rootVC.present(styleVC, animated: false)
//                }
                
                if windowScene != nil,
                   let keyWindow = windowScene?.windows.first(where: { $0.isKeyWindow }),
                   let rootVC = keyWindow.rootViewController {
                       rootVC.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
                    switch layoutType{
                    case "modal":
                        fullModalVC.modalPresentationStyle = .fullScreen
                        rootVC.present(fullModalVC, animated: false)
                        //moadalVC.presemt(modalVC, animated: false)
                    case "banner":
                        bannerVC.modalPresentationStyle = .overFullScreen
                        rootVC.present(bannerVC, animated: false)
                    default:
                        break
                    }
                       
                }
//#endif

            }
            
            
            
            print("----------------------------------")
            print("--------------Close---------------")
            
            if let close = firstLayout.close {
               // print("active: ", close.active ?? "")
                print("type: ", close.type ?? "")
                print("position: ", close.position ?? "")
                print("iconColor: ", close.icon?.color ?? "")
                print("iconStyle: ", close.icon?.style ?? "")
                print("textLabel: ", close.text?.label![lang] ?? "")
                print("textFontSize: ", close.text?.fontSize ?? "")
                print("textColor: ", close.text?.color ?? "")
                
            }
            
            print("----------------------------------")
            print("--------------Extra---------------")
            
            if let extra = firstLayout.extra {
                
                print("transition: ", extra.transition ?? "")
                print("bannerAction: ", extra.banner?.action ?? "")
                print("bannerDuration: ", extra.banner?.duration ?? "")
                print("overlayAction: ", extra.overlay?.action ?? "")
                print("overlayColor: ", extra.overlay?.color ?? "")
                
            }
            
            print("----------------------------------")
            print("--------------Blocks---------------")
            
            if let blocks = firstLayout.blocks {
                print("blocksLayer:", blocks.align ?? "")
                
                if let blockArray = blocks.order {
                    for block in blockArray {
                        switch block {
                        case .image(let imageBlock):
                            
                            print("--------------Image Block---------------")
                            print("typeImage: ", imageBlock.type ?? "")
                            print("orderImage: ", imageBlock.order ?? "")
                            print("urlImage: ", imageBlock.url ?? "")
                            print("altImage: ", imageBlock.alt ?? "")
                            print("linkImage: ", imageBlock.link ?? "boş")
                            print("radiusImage: ", imageBlock.radius ?? "")
                            print("marginImage: ", imageBlock.margin ?? "")
                            
                            
                        case .spacer(let spacerBlock):
                            
                            print("----------------------------------")
                            print("--------------Spacer Block---------------")
                            print("typeSpacer: ", spacerBlock.type ?? "")
                            print("orderSpacer: ", spacerBlock.order ?? "")
                            print("verticalSpacingSpacer: ", spacerBlock.verticalSpacing ?? "")
                            print("fillAvailableSpacingSpacer: ", spacerBlock.fillAvailableSpacing ?? "")
                            
                            
                        case .text(let textBlock):
                            print("----------------------------------")
                            print("--------------Text Block---------------")
                            print("typeText: ", textBlock.type ?? "")
                            print("orderText: ", textBlock.order ?? "")
                            print("contentText: ", textBlock.content![lang]!)
                            print("actionText: ", textBlock.action ?? "")
                            print("fontFamilyText: ", textBlock.fontFamily ?? "")
                            print("fontWeightText: ", textBlock.fontWeight ?? "")
                            print("fontSizeText: ", textBlock.fontSize ?? "")
                            print("underscoreText: ", textBlock.underscore ?? "")
                            print("italicText: ", textBlock.italic ?? "")
                            print("colorText: ", textBlock.color ?? "")
                            print("textAlignmentText: ", textBlock.textAlignment ?? "")
                            print("horizontalMarginText: ", textBlock.horizontalMargin ?? "")
                            
                            
                        case .buttonGroup(let buttonGroupBlock):
                            print("----------------------------------")
                            print("--------------ButtonGroup Block---------------")
                            print("typeButtonGroup: ", buttonGroupBlock.type ?? "")
                            print("orderButtonGroup: ", buttonGroupBlock.order ?? "")
                            print("buttonGroupTypeButtonGroup: ", buttonGroupBlock.buttonGroupType ?? "")
                            
                            if let buttonsArray = buttonGroupBlock.buttons{
                                
                                for button in buttonsArray {
                                    
                                    print("labelButtonGroup: ", button.label?[lang])
                                    print("actionButtonGroup: ", button.action ?? "")
                                    print("fontFamilyButtonGroup: ", button.fontFamily ?? "")
                                    print("fontWeightButtonGroup: ", button.fontWeight ?? "")
                                    print("fontSizeButtonGroup: ", button.fontSize ?? "")
                                    print("underscoreButtonGroup: ", button.underscore ?? "")
                                    print("italicButtonGroup: ", button.italic ?? "")
                                    print("textColorButtonGroup: ", button.textColor ?? "")
                                    print("backgroundColorButtonGroup: ", button.backgroundColor ?? "")
                                    print("borderColorButtonGroup: ", button.borderColor ?? "")
                                    print("borderRadiusButtonGroup: ", button.borderRadius ?? "")
                                    print("horizontalSizeButtonGroup: ", button.horizontalSize ?? "")
                                    print("verticalSizeButtonGroup: ", button.verticalSize ?? "")
                                    print("buttonPositionButtonGroup: ", button.buttonPosition ?? "")
                                    print("marginButtonGroup: ", button.margin ?? "")
                                    print("----------------------------------")
                                }
                            }
                        }
                    }
                }
            }

            
        }
    }

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
   /* public func customInAppFunction(userInfo: [AnyHashable: Any]) {

        if let layoutString = userInfo["layouts"] as? String {
            
            if let data = layoutString.data(using: .utf8) {
                
                do {
                    let defaultLang = userInfo["defaultLang"] as? String ?? "en"
                    
                    if let layoutsArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        
                        if let firstLayout = layoutsArray.first {
                            
                            if let styleDict = firstLayout["style"] as? [String: Any] {
                                
                                let navigationalArrows = styleDict["navigationalArrows"] as? String ?? "" //it has to be boolean. for carousels.
                               
                                let radius = styleDict["radius"] as? Int //it has to be Int. Corner Radius def: 4
                                
                                let bgColor = styleDict["bgColor"] as? String ?? ""
                                
                                let bgImage = styleDict["bgImage"] as? String ?? ""
                                
                                let bgImageMask = styleDict["bgImageMask"] as? Bool  //it has to be boolean.
                                
                                let bgImageColor = styleDict["bgImageColor"] as? String ?? ""
                                
                                let verticalPosition = styleDict["verticalPosition"] as? String ?? ""
                                
                                let horizontalPosition = styleDict["horizontalPosition"] as? String ?? ""
                                
                                print("-------------------------")
                                print("Navigational Arrows: \(navigationalArrows)")
                                print("Radius: \(radius)")
                                print("Background Color: \(bgColor)")
                                print("Background Image: \(bgImage)")
                                print("Image Mask: \(bgImageMask)")
                                print("Image Mask Color: \(bgImageColor)")
                                print("Vertical Position: \(verticalPosition)")
                                print("Horizontal Position: \(horizontalPosition)")
                            }
                            
                            if let closeDict = firstLayout["close"] as? [String: Any] {
                                
                                let isActive = closeDict["active"] as? String ?? "" //it has to be boolean. Display Close Button if checked.
                                
                                let type = closeDict["type"] as? String ?? "" //icon text
                              
                                let position = closeDict["position"] as? String ?? "" //left right + modals -> outside-right, outside-left
                                
                                print("-------------------------")
                                
                                print("Close Active: \(isActive)")
                                print("Close Type: \(type)")
                                print("Close Position: \(position)")
                                
                                
                                if let iconDict = closeDict["icon"] as? [String: Any] {
                                    
                                    let iconColor = iconDict["color"] as? String ?? ""
                                    
                                    let iconStyle = iconDict["style"] as? String ?? "" //Icon Style: Filled, Outlined, Basic
                                    
                                    print("Icon Color: \(iconColor)")
                                    print("Icon Style: \(iconStyle)")
                            
                                }
                                
                                if let textDict = closeDict["text"] as? [String: Any] {
                                    
                                    let fontSize = textDict["fontSize"] as? String ?? "" //Text Size (px)
                                    
                                    let textColor = textDict["color"] as? String ?? "" //Text color
                                    
                                    print("Text Font Size: \(fontSize)")
                                    print("Text Color: \(textColor)")
                                    
                                   if let labelDict = textDict["label"] as? [String: String] {
                                        
                                       let localizedlabel = labelDict[defaultLang] ?? labelDict.values.first ?? ""
                                       
                                       print("Label: \(localizedlabel)")
                                    }
                                }
                            }
                            
                            if let extraDict = firstLayout["extra"] as? [String: Any] {
                                
                                if let bannerDict = extraDict["banner"] as? [String: Any] {
                                    
                                    let bannerAction = bannerDict["action"] as? String ?? "" //url, deeplink
                                    
                                    let bannerDuration = bannerDict["duration"] as? String ?? "" //it has to be Int. second -> display duration
                                    
                                    print("-------------------------")
                                    
                                    print("Banner Action: \(bannerAction)")
                                    print("Banner Duration: \(bannerDuration)")
                                    
                                }
                                
                                if let overlayDict = extraDict["overlay"] as? [String: Any] {
                                    
                                    let overlayAction = overlayDict["action"] as? String ?? "" // close, no-action
                                    
                                    let overlayColor = overlayDict["color"] as? String ?? "" // hex code
                                    
                                    print("Overlay Action: \(overlayAction)")
                                    print("Overlay Color: \(overlayColor)")
                                }
                                
                                let transition = extraDict["transition"] as? String ?? "" // right 2 left, left 2 right, top 2 bottom, bottom 2 top, no tran
                                
                                print("Transition Effect: \(transition)")
                                
                            }
                            
                            if let blocksDict = firstLayout["blocks"] as? [String: Any] {
                                
                                let align = blocksDict["align"] as? String ?? "" // "top" | "center" | "bottom"; // Vertical alignment of the modal
                                
                                print("-------------------------")
                                print("Block Align: \(align)")
                                
                                
                                if let orderArray = blocksDict["order"] as? [[String: Any]] {
                                    
                                    for block in orderArray {
                                        
                                        if let type = block["type"] as? String {
                                            
                                            switch type {
                                                
                                            case "image":
                                                
                                                let order = block["order"] as? String ?? "" //it has to be Int. Determines position in the modal.
                                                
                                                let url = block["url"] as? String ?? ""
                                                
                                                let alt = block["alt"] as? String ?? "" //Accessibility Text
                                                
                                                let link = block["link"] as? String ?? "boş" //Link Image | deeplink, external url ??
                                                
                                                let radius = block["radius"] as? String ?? "" //it has to be Int, corner radius
                                                
                                                let margin = block["margin"] as? String ?? "" //it has to be Int, raw pixel
                                                
                                                print("Image Block Found!")
                                                print("Order: \(order)")
                                                print("Image URL: \(url)")
                                                print("Alt Text: \(alt)")
                                                print("Link: \(link)")
                                                print("Radius: \(radius)")
                                                print("Margin: \(margin)")
                                                print("-------------------------")
                                                
                                            case "spacer":
                                                
                                                let order = block["order"] as? String ?? "" //it has to be int, determines position in the modal.
                                                
                                                let verticalSpacing = block["verticalSpacing"] as? String ?? ""
                                                
                                                let fillAvailableSpacing = block["fillAvailableSpacing"] as? String ?? "" //it has to be boolean, def:false
                                                
                                                print("Spacer Block Found!")
                                                print("Order: \(order)")
                                                print("Vertical Spacing: \(verticalSpacing)")
                                                print("Fill Available Spacing: \(fillAvailableSpacing)")
                                                print("-------------------------")
                                                
                                            case "text":
                                                
                                                let order = block["order"] as? String ?? "" //it has to be Int, determines position in the modal
                                                
                                                if let contentDict = block["content"] as? [String: String] {
                                                    
                                                    let localizedContent = contentDict[defaultLang] ?? contentDict.values.first ?? ""
                                                    
                                                    print("Text Block Found!")
                                                    print("Content: \(localizedContent)")
                                                }
                                                
                                                let action = block["action"] as? String ?? ""
                                                
                                                let fontFamily = block["fontFamily"] as? String ?? "" //monospace cursive sans-serif
                                                
                                                let fontWeight = block["fontWeight"] as? String ?? "" //"normal" | "bold" | "italic"
                                                
                                                let fontSize = block["fontSize"] as? String ?? ""
                                                
                                                let underscore = block["underscore"] as? String ?? "" //it has to be boolean, textStyle
                                                
                                                let italic = block["italic"] as? String ?? "" //it has to be boolean
                                                
                                                let color = block["color"] as? String ?? "" //Hex color code
                                                
                                                let textAlignment = block["textAlignment"] as? String ?? "" // left center right
                                                
                                                let horizontalMargin = block["horizontalMargin"] as? String ?? "" //it has to be Int, raw px
                                                
                                                
                                                print("Order: \(order)")
                                                print("Action: \(action)")
                                                print("Font Family: \(fontFamily)")
                                                print("Font Weight: \(fontWeight)")
                                                print("Font Size: \(fontSize)")
                                                print("Color: \(color)")
                                                print("Horizontal Margin: \(horizontalMargin)")
                                                print("Alignment: \(textAlignment)")
                                                print("Italic: \(italic)")
                                                print("Underscore: \(underscore)")
                                                print("-------------------------")
                                                
                                            case "buttonGroup":
                                                
                                                let order = block["order"] as? String ?? "" //it has to be Int, determines position in the modal
                                                
                                                let buttonGroupType = block["buttonGroupType"] as? String ?? "" //  SingleVertical = "single-vertical",          One button centered vertically                               DoubleVertical = "double-vertical",          Two buttons stacked vertically (e.g., top and bottom) DoubleHorizontal = "double-horizontal",      Two buttons side by side (e.g., left and right) SingleCompactVertical = "single-compact-vertical",    One short button vertically aligned DoubleCompactVertical = "double-compact-vertical",   Two short buttons stacked vertically (top and bottom)
                                                
                                                print("Button Group Block Found!")
                                                print("Order: \(order)")
                                                print("Button Group Type: \(buttonGroupType)")
                                                
                                                if let buttonsArray = block["buttons"] as? [[String: Any]] {
                                                    
                                                    for button in buttonsArray {
                                                        
                                                        if let labelDict = button["label"] as? [String: String] {
                                                            
                                                            let label = labelDict[defaultLang] ?? labelDict.values.first ?? ""
                                                            
                                                            print("Button Found!")
                                                            print("Label: \(label)")
                                                            
                                                        }

                                                        let action = button["action"] as? String ?? "boş"
                                                        
                                                        let fontFamily = button["fontFamily"] as? String ?? ""
                                                        
                                                        let fontWeight = button["fontWeight"] as? String ?? ""
                                                        
                                                        let fontSize = button["fontSize"] as? String ?? ""
                                                        
                                                        let textColor = button["textColor"] as? String ?? ""
                                                        
                                                        let backgroundColor = button["backgroundColor"] as? String ?? ""
                                                        
                                                        let borderColor = button["borderColor"] as? String ?? ""
                                                        
                                                        let borderRadius = button["borderRadius"] as? String ?? ""
                                                        
                                                        let horizontalSize = button["horizontalSize"] as? String ?? ""
                                                        
                                                        let verticalSize = button["verticalSize"] as? String ?? ""
                                                        
                                                        let buttonPosition = button["buttonPosition"] as? String ?? ""
                                                        
                                                        let margin = button["margin"] as? String ?? ""
                                                        
                                                        
                                                        
                                                        print("Action: \(action)")
                                                        print("Font Family: \(fontFamily)")
                                                        print("Font Weight: \(fontWeight)")
                                                        print("Font Size: \(fontSize)")
                                                        print("Text Color: \(textColor)")
                                                        print("Background Color: \(backgroundColor)")
                                                        print("Border Color: \(borderColor)")
                                                        print("Border Radius: \(borderRadius)")
                                                        print("Horizontal Size: \(horizontalSize)")
                                                        print("Vertical Size: \(verticalSize)")
                                                        print("Position: \(buttonPosition)")
                                                        print("Margin: \(margin)")
                                                        print("-------------------------")
                                                        
                                                    }
                                                    
                                                }
                                                
                                        default:
                                                print("Unknown Block Type: \(type)")

                                                
                                            }
                                            
                                        }
                                        
                                    }
                                    
                                }
                                
                            }
                            
                        }
                    }
                    
                }catch {
                    print("JSON Parsing Hatası: \(error)")
                }
            }
        }
        
    }*/
    
}
