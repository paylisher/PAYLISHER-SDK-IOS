//
//  CustomInAppPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 18.02.2025.
//

import Foundation


fileprivate func decodeIntOrString<K: CodingKey>(
    _ container: KeyedDecodingContainer<K>,
    forKey key: K
) -> Int? {
    if let intVal = try? container.decode(Int.self, forKey: key) { return intVal }
    if let strVal = try? container.decode(String.self, forKey: key),
       let parsed = Int(strVal) { return parsed }
    return nil
}


public struct CustomInAppPayload: Codable {
   
    let pushId: String?
    let condition: Condition?

    let defaultLang: String?
   
    let layoutType: String?
   
    let layouts: [Layout]?

    struct Condition: Codable {
        let target: String?
        let displayTime: Int64?
        let expireDate: Int64?
        let delay: Int?

        private enum CodingKeys: String, CodingKey {
            case target
            case displayTime
            case expireDate
            case delay
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.target = try? container.decode(String.self, forKey: .target)
            self.displayTime = Self.decodeInt64(container, forKey: .displayTime)
            self.expireDate = Self.decodeInt64(container, forKey: .expireDate)
            self.delay = Self.decodeInt(container, forKey: .delay)
        }

        private static func decodeInt64(
            _ container: KeyedDecodingContainer<CodingKeys>,
            forKey key: CodingKeys
        ) -> Int64? {
            if let raw = try? container.decode(String.self, forKey: key),
               let value = Int64(raw) {
                return value
            }
            if let value = try? container.decode(Int64.self, forKey: key) {
                return value
            }
            if let value = try? container.decode(Int.self, forKey: key) {
                return Int64(value)
            }
            return nil
        }

        private static func decodeInt(
            _ container: KeyedDecodingContainer<CodingKeys>,
            forKey key: CodingKeys
        ) -> Int? {
            if let raw = try? container.decode(String.self, forKey: key),
               let value = Int(raw) {
                return value
            }
            return try? container.decode(Int.self, forKey: key)
        }
    }
    
    
    struct Layout: Codable {
        
        let style: Style?
        
        let close: Close?
        
        let extra: Extra?
        
        let blocks: Blocks?

        struct Style: Codable {
            
            let navigationalArrows: Bool? //bool olmalı
            
            let radius: Int? //int olmalı
            
            let bgColor: String?
            
            let bgImage: String?
            
            let bgImageMask: Bool? //bool olmalı
            
            let bgImageColor: String?

            let bgBottomInset: Int?

            let bgBottomColor: String?

            let verticalPosition: String?

            let horizontalPosition: String?

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                // navigationalArrows
                if let arrowsBool = try? container.decode(Bool.self, forKey: .navigationalArrows) {
                    self.navigationalArrows = arrowsBool
                } else if let arrowsStr = try? container.decode(String.self, forKey: .navigationalArrows) {
                    self.navigationalArrows = (arrowsStr.lowercased() == "true")
                } else {
                    self.navigationalArrows = false
                }

                // radius
                if let radiusStr = try? container.decode(String.self, forKey: .radius),
                   let intVal = Int(radiusStr) {
                    self.radius = intVal
                } else {
                    self.radius = nil
                }

                self.bgColor = try? container.decode(String.self, forKey: .bgColor)
                self.bgImage = try? container.decode(String.self, forKey: .bgImage)

                // bgImageMask
                if let maskStr = try? container.decode(String.self, forKey: .bgImageMask) {
                    self.bgImageMask = (maskStr == "true")
                } else {
                    self.bgImageMask = false
                }

                self.bgImageColor = try? container.decode(String.self, forKey: .bgImageColor)

                // bgBottomInset (accept Int or numeric String)
                if let intVal = try? container.decode(Int.self, forKey: .bgBottomInset) {
                    self.bgBottomInset = intVal
                } else if let strVal = try? container.decode(String.self, forKey: .bgBottomInset),
                          let parsed = Int(strVal) {
                    self.bgBottomInset = parsed
                } else {
                    self.bgBottomInset = nil
                }

                self.bgBottomColor = try? container.decode(String.self, forKey: .bgBottomColor)

                self.verticalPosition = try? container.decode(String.self, forKey: .verticalPosition)
                self.horizontalPosition = try? container.decode(String.self, forKey: .horizontalPosition)
            }
        }

        struct Close: Codable {
            
            let active: Bool? //bool olmalı
            
            let type: String?
            
            let position: String?
            
            let icon: Icon?
            
            let text: CloseText?
            
            
            struct Icon: Codable {
                
                let color: String?
                
                let style: String?
                
                init(from decoder: Decoder) throws {
                    
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.color = try? container.decode(String.self, forKey: .color)
                    self.style = try? container.decode(String.self, forKey: .style)
                    
                }
            }
            
            
            struct CloseText: Codable {
               
                let label: [String: String]?
                
                let fontSize: Int? // int olmalı
                
                let color: String?
                
                init(from decoder: Decoder) throws {
                    
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.label = try? container.decode([String: String].self, forKey: .label)
                    
                    if let fontSizeStr = try? container.decode(String.self, forKey: .fontSize),
                       let intVal = Int(fontSizeStr) {
                        self.fontSize = intVal
                    } else {
                        self.fontSize = nil
                    }
                    
                    self.color = try? container.decode(String.self, forKey: .color)
                    
                    
                }
            }
            
            init(from decoder: Decoder) throws {
                
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                if let activeStr = try? container.decode(String.self, forKey: .active) {
                    self.active = (activeStr == "true")
                } else {
                    self.active = false
                }
                //self.verticalPosition = try? container.decode(String.self, forKey: .verticalPosition)
                self.type = try? container.decode(String.self, forKey: .type)
                self.position = try? container.decode(String.self, forKey: .position)
                self.icon = try? container.decode(CustomInAppPayload.Layout.Close.Icon.self, forKey: .icon)
                self.text = try? container.decode(CustomInAppPayload.Layout.Close.CloseText.self, forKey: .text)
                
                
            }
            
        }
        
        
        struct Extra: Codable {
            
            let banner: Banner?
            
            let overlay: Overlay?
            
            let transition: String?
            
            struct Banner: Codable {
                
                let action: String?
                
                let duration: Int? //int olmalı
                
                init(from decoder: Decoder) throws {
                    
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.action = try? container.decode(String.self, forKey: .action)
                    
                    if let durationStr = try? container.decode(String.self, forKey: .duration),
                       let intVal = Int(durationStr) {
                        self.duration = intVal
                    } else {
                        self.duration = nil
                    }
                    
                    
                }
                
            }
            
            struct Overlay: Codable {
                
                let action: String?
                
                let color: String?
                
                init(from decoder: Decoder) throws {
                    
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.action = try? container.decode(String.self, forKey: .action)
                    self.color = try? container.decode(String.self, forKey: .color)
                    
                }
            }
            
            init(from decoder: Decoder) throws {
                
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.banner = try? container.decode(CustomInAppPayload.Layout.Extra.Banner.self, forKey: .banner)
                self.overlay = try? container.decode(CustomInAppPayload.Layout.Extra.Overlay.self, forKey: .overlay)
                self.transition = try? container.decode(String.self, forKey: .transition)
                
            }
            
        }
        
        
        struct Blocks: Codable {
            
            let align: String?
            
            let order: [Block]?
            
            
            enum Block: Codable {

                case text(TextBlock)

                case image(ImageBlock)

                case spacer(SpacerBlock)

                case buttonGroup(ButtonGroupBlock)

                case button(ButtonGroupBlock.ButtonBlock)

                case unknown(String)

                private enum CodingKeys: String, CodingKey {
                    case type
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let blockType = try container.decode(String.self, forKey: .type)

                    switch blockType {
                    case "text":
                        self = .text(try TextBlock(from: decoder))
                    case "image":
                        self = .image(try ImageBlock(from: decoder))
                    case "spacer":
                        self = .spacer(try SpacerBlock(from: decoder))
                    case "buttonGroup":
                        self = .buttonGroup(try ButtonGroupBlock(from: decoder))
                    case "button":
                        self = .button(try ButtonGroupBlock.ButtonBlock(from: decoder))
                    default:
                        print("⚠️ [Paylisher] Unknown block type: \(blockType) - skipping")
                        self = .unknown(blockType)
                    }
                }

                func encode(to encoder: Encoder) throws {
                    switch self {
                    case .text(let textBlock):
                        try textBlock.encode(to: encoder)
                    case .image(let imageBlock):
                        try imageBlock.encode(to: encoder)
                    case .spacer(let spacerBlock):
                        try spacerBlock.encode(to: encoder)
                    case .buttonGroup(let buttonGroupBlock):
                        try buttonGroupBlock.encode(to: encoder)
                    case .button(let buttonBlock):
                        try buttonBlock.encode(to: encoder)
                    case .unknown:
                        break
                    }
                }
            }
            
            struct ImageBlock: Codable {
                let type: String?
                let order: Int? //int olmalı

                let url: String?
                let alt: String?
                let link: String?

                let radius: Int? //int olmalı
                let margin: Int? //int olmalı
                let marginTop: Int?
                let marginBottom: Int?

                init(from decoder: Decoder) throws {

                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    self.type = try? container.decode(String.self, forKey: .type)

                    if let orderStr = try? container.decode(String.self, forKey: .order),
                       let intVal = Int(orderStr) {
                        self.order = intVal
                    } else {
                        self.order = nil
                    }

                    self.url = try? container.decode(String.self, forKey: .url)
                    self.alt = try? container.decode(String.self, forKey: .alt)
                    self.link = try? container.decode(String.self, forKey: .link)

                    if let radiusStr = try? container.decode(String.self, forKey: .radius),
                       let intVal = Int(radiusStr) {
                        self.radius = intVal
                    } else {
                        self.radius = nil
                    }

                    if let marginStr = try? container.decode(String.self, forKey: .margin),
                       let intVal = Int(marginStr) {
                        self.margin = intVal
                    } else {
                        self.margin = nil
                    }

                    self.marginTop = decodeIntOrString(container, forKey: .marginTop)
                    self.marginBottom = decodeIntOrString(container, forKey: .marginBottom)
                }

            }
            
            
            
            
            struct SpacerBlock: Codable {
                let type: String?
                let order: Int? //int olmalı

                let verticalSpacing: Int? //int olmalı
                let fillAvailableSpacing: Bool? //bool olmalı
                let marginTop: Int?
                let marginBottom: Int?

                init(from decoder: Decoder) throws {

                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    self.type = try? container.decode(String.self, forKey: .type)

                    if let orderStr = try? container.decode(String.self, forKey: .order),
                       let intVal = Int(orderStr) {
                        self.order = intVal
                    } else {
                        self.order = nil
                    }

                    if let verticalSpacingStr = try? container.decode(String.self, forKey: .verticalSpacing),
                       let intVal = Int(verticalSpacingStr) {
                        self.verticalSpacing = intVal
                    } else {
                        self.verticalSpacing = nil
                    }

                    if let fillAvailableSpacingStr = try? container.decode(String.self, forKey: .fillAvailableSpacing) {
                        self.fillAvailableSpacing = (fillAvailableSpacingStr == "true")
                    } else {
                        self.fillAvailableSpacing = false
                    }

                    self.marginTop = decodeIntOrString(container, forKey: .marginTop)
                    self.marginBottom = decodeIntOrString(container, forKey: .marginBottom)
                }


            }
            
            struct TextBlock: Codable {
                let type: String?
                let order: Int? //int olmalı
                
                let content: [String: String]?
                let action: String?
                
                let fontFamily: String?
                let fontWeight: String?
                let fontSize: String?
                let underscore: Bool? //bool olmalı
                let italic: Bool? //bool olmalı
                let color: String?
                let textAlignment: String?
                
                let horizontalMargin: Int? //int olmalı
                let marginTop: Int?
                let marginBottom: Int?

                init(from decoder: Decoder) throws {

                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    self.type = try? container.decode(String.self, forKey: .type)

                    if let orderStr = try? container.decode(String.self, forKey: .order),
                       let intVal = Int(orderStr) {
                        self.order = intVal
                    } else {
                        self.order = nil
                    }

                    self.content = try? container.decode([String: String].self, forKey: .content)
                    self.action = try? container.decode(String.self, forKey: .action)
                    self.fontFamily = try? container.decode(String.self, forKey: .fontFamily)
                    self.fontWeight = try? container.decode(String.self, forKey: .fontWeight)
                    self.fontSize = try? container.decode(String.self, forKey: .fontSize)

                    if let underscoreStr = try? container.decode(String.self, forKey: .underscore) {
                        self.underscore = (underscoreStr == "true")
                    }else{
                        self.underscore = false
                    }

                    if let italicStr = try? container.decode(String.self, forKey: .italic) {
                        self.italic = (italicStr == "true")
                    }else{
                        self.italic = false
                    }

                    self.color = try? container.decode(String.self, forKey: .color)
                    self.textAlignment = try? container.decode(String.self, forKey: .textAlignment)

                    if let horizontalMarginStr = try? container.decode(String.self, forKey: .horizontalMargin),
                       let intVal = Int(horizontalMarginStr) {
                        self.horizontalMargin = intVal
                    } else {
                        self.horizontalMargin = nil
                    }

                    self.marginTop = decodeIntOrString(container, forKey: .marginTop)
                    self.marginBottom = decodeIntOrString(container, forKey: .marginBottom)
                }

            }
            
        

            struct ButtonGroupBlock: Codable {
                let type: String?
                let order: Int? //int olmalı

                let buttonGroupType: String?
                let buttons: [ButtonBlock]?
                let marginTop: Int?
                let marginBottom: Int?
                /// Vertical inter-button gap. Banner: percent of banner height (0–100).
                /// Modal/fullscreen: raw pt. Only honored for `double-vertical` groups —
                /// `double-horizontal` always butts the two slots up against each other
                /// (SDK locks 50/50). Optional; missing/legacy payloads default to 0.
                let buttonGap: Int?

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.type = try? container.decode(String.self, forKey: .type)
                    self.order = decodeIntOrString(container, forKey: .order)
                    self.buttonGroupType = try? container.decode(String.self, forKey: .buttonGroupType)
                    self.buttons = try? container.decode([ButtonBlock].self, forKey: .buttons)
                    self.marginTop = decodeIntOrString(container, forKey: .marginTop)
                    self.marginBottom = decodeIntOrString(container, forKey: .marginBottom)
                    self.buttonGap = decodeIntOrString(container, forKey: .buttonGap)
                }
                
                
                
                
                struct ButtonBlock: Codable {
                    let label: [String: String]?
                    let action: String?
                    
                    let fontFamily: String?
                    let fontWeight: String?
                    let fontSize: String?
                    
                    let underscore: Bool? //bool olmalı
                    let italic: Bool? //bool olmalı
                    
                    let textColor: String?
                    let backgroundColor: String?
                    let borderColor: String?
                    let borderRadius: Int? //int olmalı
                    
                    let horizontalSize: String?
                    let verticalSize: String?
                    let buttonPosition: String?
                    
                    let margin: Int? //int olmalı
                    
                    init(from decoder: Decoder) throws {
                        
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        
                        self.label = try? container.decode([String: String].self, forKey: .label)
                        self.action = try? container.decode(String.self, forKey: .action)
                        self.fontFamily = try? container.decode(String.self, forKey: .fontFamily)
                        self.fontWeight = try? container.decode(String.self, forKey: .fontWeight)
                        self.fontSize = try? container.decode(String.self, forKey: .fontSize)
                        
                        if let underscoreStr = try? container.decode(String.self, forKey: .underscore) {
                            self.underscore = (underscoreStr == "true")
                        }else{
                            self.underscore = false
                        }
                        
                        if let italicStr = try? container.decode(String.self, forKey: .italic) {
                            self.italic = (italicStr == "true")
                        }else{
                            self.italic = false
                        }
                        
                        self.textColor = try? container.decode(String.self, forKey: .textColor)
                        self.backgroundColor = try? container.decode(String.self, forKey: .backgroundColor)
                        self.borderColor = try? container.decode(String.self, forKey: .borderColor)
                        
                        if let borderRadiusStr = try? container.decode(String.self, forKey: .borderRadius),
                           let intVal = Int(borderRadiusStr) {
                            self.borderRadius = intVal
                        } else {
                            self.borderRadius = nil
                        }
                        
                        self.horizontalSize = try? container.decode(String.self, forKey: .horizontalSize)
                        self.verticalSize = try? container.decode(String.self, forKey: .verticalSize)
                        self.buttonPosition = try? container.decode(String.self, forKey: .buttonPosition)
                        
                        if let marginStr = try? container.decode(String.self, forKey: .margin),
                           let intVal = Int(marginStr) {
                            self.margin = intVal
                        } else {
                            self.margin = nil
                        }
                        
                    }

                }

            }
        }
    }
}
