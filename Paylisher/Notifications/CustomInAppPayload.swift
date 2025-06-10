//
//  CustomInAppPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 18.02.2025.
//

import Foundation


public struct CustomInAppPayload: Codable {
   
    let defaultLang: String?
   
    let layoutType: String?
   
    let layouts: [Layout]?
    
    
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
            
            let verticalPosition: String?
            
            let horizontalPosition: String?
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                // navigationalArrows
                self.navigationalArrows = try? container.decode(Bool.self, forKey: .navigationalArrows)
                
                
                self.radius = try? container.decode(Int.self, forKey: .radius)
                
                self.bgColor = try? container.decode(String.self, forKey: .bgColor)
                self.bgImage = try? container.decode(String.self, forKey: .bgImage)
                
                // bgImageMask
                self.bgImageMask = try? container.decode(Bool.self, forKey: .bgImageMask)//çalışmıyo
                
                self.bgImageColor = try? container.decode(String.self, forKey: .bgImageColor)//görsel varsa görünmüyor
                
                self.verticalPosition = try? container.decode(String.self, forKey: .verticalPosition)
                self.horizontalPosition = try? container.decode(String.self, forKey: .horizontalPosition)// mobilde kullanılmıyor
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
                
                let fontSize: String? 
                
                let color: String?
                
                init(from decoder: Decoder) throws {
                    
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.label = try? container.decode([String: String].self, forKey: .label)
                    
                    self.fontSize = try? container.decode(String.self, forKey: .fontSize)
                    
                    self.color = try? container.decode(String.self, forKey: .color)
                    
                    
                }
            }
            
            init(from decoder: Decoder) throws {
                
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.active = try? container.decode(Bool.self, forKey: .active)
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
                    
                    self.duration = try? container.decode(Int.self, forKey: .duration)
                    
                    
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
                    default:
                        throw DecodingError.dataCorruptedError(
                            forKey: .type,
                            in: container,
                            debugDescription: "Unknown block type: \(blockType)"
                        )
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
                
                init(from decoder: Decoder) throws {
                    
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.type = try? container.decode(String.self, forKey: .type)
                    
                    self.order = try? container.decode(Int.self, forKey: .order)
                    
                    self.url = try? container.decode(String.self, forKey: .url)
                    self.alt = try? container.decode(String.self, forKey: .alt)
                    self.link = try? container.decode(String.self, forKey: .link)
                    
                    self.radius = try? container.decode(Int.self, forKey: .radius)
                    
                    self.margin = try? container.decode(Int.self, forKey: .margin)
                    
                }
                
            }
            
            
            
            
            struct SpacerBlock: Codable {
                let type: String?
                let order: Int? //int olmalı
                
                let verticalSpacing: String?
                let fillAvailableSpacing: Bool? //bool olmalı
                
                init(from decoder: Decoder) throws {
                    
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.type = try? container.decode(String.self, forKey: .type)
                    
                    self.order = try? container.decode(Int.self, forKey: .order)
                    
                    self.verticalSpacing = try? container.decode(String.self, forKey: .verticalSpacing)
                    
                    self.fillAvailableSpacing = try? container.decode(Bool.self, forKey: .fillAvailableSpacing)
                    
                    
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
                
                init(from decoder: Decoder) throws {
                    
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.type = try? container.decode(String.self, forKey: .type)
                    
                    self.order = try? container.decode(Int.self, forKey: .order)
                    
                    self.content = try? container.decode([String: String].self, forKey: .content)
                    self.action = try? container.decode(String.self, forKey: .action)
                    self.fontFamily = try? container.decode(String.self, forKey: .fontFamily)
                    self.fontWeight = try? container.decode(String.self, forKey: .fontWeight)
                    self.fontSize = try? container.decode(String.self, forKey: .fontSize)
                    
                    self.underscore = try? container.decode(Bool.self, forKey: .underscore)
                    
                    self.italic = try? container.decode(Bool.self, forKey: .italic)
                    
                    self.color = try? container.decode(String.self, forKey: .color)
                    self.textAlignment = try? container.decode(String.self, forKey: .textAlignment)
                    
                    self.horizontalMargin = try? container.decode(Int.self, forKey: .horizontalMargin)
                }
                
            }
            
        

            struct ButtonGroupBlock: Codable {
                let type: String?
                let order: Int? //int olmalı
                
                let buttonGroupType: String?
                let buttons: [ButtonBlock]?
                
                
                
                
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
                        
                        self.underscore = try? container.decode(Bool.self, forKey: .underscore)
                        
                        self.italic = try? container.decode(Bool.self, forKey: .italic)
                        
                        self.textColor = try? container.decode(String.self, forKey: .textColor)
                        self.backgroundColor = try? container.decode(String.self, forKey: .backgroundColor)
                        self.borderColor = try? container.decode(String.self, forKey: .borderColor)
                        
                        self.borderRadius = try? container.decode(Int.self, forKey: .borderRadius)
                        
                        self.horizontalSize = try? container.decode(String.self, forKey: .horizontalSize)
                        self.verticalSize = try? container.decode(String.self, forKey: .verticalSize)
                        self.buttonPosition = try? container.decode(String.self, forKey: .buttonPosition)
                        
                        self.margin = try? container.decode(Int.self, forKey: .margin)
                        
                    }
                    
                }
                
                init(from decoder: Decoder) throws {
                    
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.type = try? container.decode(String.self, forKey: .type)
                    
                    self.order = try? container.decode(Int.self, forKey: .order)
                    
                    self.buttonGroupType = try? container.decode(String.self, forKey: .buttonGroupType)
                    self.buttons = try? container.decode([ButtonBlock].self, forKey: .buttons)
                    
                }
            }
        }
    }
}

