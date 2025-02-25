//
//  CustomInAppPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 18.02.2025.
//

import Foundation


struct CustomInAppPayload: Codable {
   
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
                if let arrowsStr = try? container.decode(String.self, forKey: .navigationalArrows) {
                    self.navigationalArrows = (arrowsStr == "true")
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
                let order: String? //int olmalı
                
                let url: String?
                let alt: String?
                let link: String?
                
                let radius: String? //int olmalı
                let margin: String? //int olmalı
            }
            
            struct SpacerBlock: Codable {
                let type: String?
                let order: String? //int olmalı
                
                let verticalSpacing: String? //int olmalı
                let fillAvailableSpacing: String? //bool olmalı
                
               /* init(from decoder: Decoder) throws {
                    
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.type = try? container.decode(String.self, forKey: .type)
                }*/
                
                
            }
        
            struct TextBlock: Codable {
                let type: String?
                let order: String? //int olmalı
                
                let content: [String: String]?
                let action: String?
                
                let fontFamily: String?
                let fontWeight: String?
                let fontSize: String?
                let underscore: String? //bool olmalı
                let italic: String? //bool olmalı
                let color: String?
                let textAlignment: String?
                
                let horizontalMargin: String? //int olmalı
            }

            struct ButtonGroupBlock: Codable {
                let type: String?
                let order: String? //int olmalı
                
                let buttonGroupType: String?
                let buttons: [ButtonBlock]?
            }
            
            struct ButtonBlock: Codable {
                let label: [String: String]?
                let action: String?
                
                let fontFamily: String?
                let fontWeight: String?
                let fontSize: String?
                
                let underscore: String? //bool olmalı
                let italic: String? //bool olmalı
                
                let textColor: String?
                let backgroundColor: String?
                let borderColor: String?
                let borderRadius: String? //int olmalı
                
                let horizontalSize: String?
                let verticalSize: String?
                let buttonPosition: String?
                
                let margin: String? //int olmalı
            }
        }
    }
}

