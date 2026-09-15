//
//  CustomInAppPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 18.02.2025.
//

import Foundation


// MARK: - Localized string resolution
// Mirrors Android's InAppLocalize.localize(): device language first, then the
// campaign's defaultLang, then any available translation. Keeps push + in-app
// rendering identical across iOS and Android.
extension Dictionary where Key == String, Value == String {
    func localize(_ defaultLang: String? = nil, fallback: String = "") -> String {
        // True device language, independent of the host app's localizations,
        // primary subtag only ("tr-TR" -> "tr"). Mirrors Android's
        // Locale.getDefault().language so iOS and Android resolve identically.
        let deviceLang = (Locale.preferredLanguages.first ?? Locale.current.languageCode ?? "")
            .split(separator: "-").first.map { $0.lowercased() }
        if let deviceLang = deviceLang, let value = self[deviceLang] {
            return value
        }
        if let defaultLang = defaultLang, let value = self[defaultLang] {
            return value
        }
        return self.values.first ?? fallback
    }
}


fileprivate func decodeIntOrString<K: CodingKey>(
    _ container: KeyedDecodingContainer<K>,
    forKey key: K
) -> Int? {
    if let intVal = try? container.decode(Int.self, forKey: key) { return intVal }
    if let strVal = try? container.decode(String.self, forKey: key),
       let parsed = Int(strVal) { return parsed }
    return nil
}

/// Bool that may arrive as a JSON boolean, a "true"/"false" string or 0/1. Nil when absent
/// or unparsable so each field can pick its own default (see `Close.active`).
fileprivate func decodeBoolOrString<K: CodingKey>(
    _ container: KeyedDecodingContainer<K>,
    forKey key: K
) -> Bool? {
    if let boolVal = try? container.decode(Bool.self, forKey: key) { return boolVal }
    if let strVal = try? container.decode(String.self, forKey: key) {
        switch strVal.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes": return true
        case "false", "0", "no": return false
        default: return nil
        }
    }
    if let intVal = try? container.decode(Int.self, forKey: key) { return intVal != 0 }
    return nil
}

/// String field (font sizes) that the server may send as a number.
fileprivate func decodeStringOrInt<K: CodingKey>(
    _ container: KeyedDecodingContainer<K>,
    forKey key: K
) -> String? {
    if let strVal = try? container.decode(String.self, forKey: key) { return strVal }
    if let intVal = try? container.decode(Int.self, forKey: key) { return String(intVal) }
    if let doubleVal = try? container.decode(Double.self, forKey: key) { return String(format: "%g", doubleVal) }
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

            // Background image fit / position / inner inset — parity with image
            // blocks + Studio + Android. nil → cover / center / 0.
            let bgImageFit: String?
            let bgImageAlignX: String?
            let bgImageAlignY: String?
            let bgImagePadding: Int?

            let bgBottomInset: Int?

            let bgBottomColor: String?

            /// Strip TOP curve — percent of container height (-100 to 100).
            /// Positive: softens the strip's top corners. Negative: strip
            /// extends upward into a dome that rises into the content
            /// area. 0 / nil = flat seam.
            let bgBottomRadiusTop: Int?

            let verticalPosition: String?

            let horizontalPosition: String?

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                // navigationalArrows
                self.navigationalArrows = decodeBoolOrString(container, forKey: .navigationalArrows) ?? false

                // radius
                self.radius = decodeIntOrString(container, forKey: .radius)

                self.bgColor = try? container.decode(String.self, forKey: .bgColor)
                self.bgImage = try? container.decode(String.self, forKey: .bgImage)

                // bgImageMask
                self.bgImageMask = decodeBoolOrString(container, forKey: .bgImageMask) ?? false

                self.bgImageColor = try? container.decode(String.self, forKey: .bgImageColor)

                self.bgImageFit = try? container.decode(String.self, forKey: .bgImageFit)
                self.bgImageAlignX = try? container.decode(String.self, forKey: .bgImageAlignX)
                self.bgImageAlignY = try? container.decode(String.self, forKey: .bgImageAlignY)
                self.bgImagePadding = decodeIntOrString(container, forKey: .bgImagePadding)

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

                // bgBottomRadiusTop (accept Int or numeric String — may be
                // negative, used to express an upward dome curve)
                if let intVal = try? container.decode(Int.self, forKey: .bgBottomRadiusTop) {
                    self.bgBottomRadiusTop = intVal
                } else if let strVal = try? container.decode(String.self, forKey: .bgBottomRadiusTop),
                          let parsed = Int(strVal) {
                    self.bgBottomRadiusTop = parsed
                } else {
                    self.bgBottomRadiusTop = nil
                }

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
                    
                    self.fontSize = decodeIntOrString(container, forKey: .fontSize)
                    
                    self.color = try? container.decode(String.self, forKey: .color)
                    
                    
                }
            }
            
            init(from decoder: Decoder) throws {
                
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                // Absent or unparsable → true: a fullscreen/modal without a close button (and without an
            // overlay "close" action) has NO way out for the user.
            self.active = decodeBoolOrString(container, forKey: .active) ?? true
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
                    
                    self.duration = decodeIntOrString(container, forKey: .duration)
                    
                    
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

                    // `type` OKUNAMAZSA MESAJIN TAMAMI DÜŞMEMELİ.
                    //
                    // Burada eskiden fırlatan bir decode vardı ve bu, TÜM
                    // CustomInAppPayload çözümünü iptal ediyordu: tek bir bloğun
                    // `type` alanı eksikse kullanıcı hiçbir şey görmüyordu.
                    // Sunucu tarafındaki iOS dönüşümü de tipi olmayan bloğu
                    // olduğu gibi geçiriyor (Fcm.Messaging.Service
                    // transformBlocksToIOSFormat: `if (!block.type) return block`),
                    // yani böyle bir blok cihaza gerçekten ulaşabiliyor.
                    //
                    // Android aynı durumda bloğu atlayıp geri kalanını çiziyor
                    // (InAppLayoutBlockDeserializer: bilinmeyen tip → SpacerBlock).
                    // Yani aynı kampanya Android'de görünüp iOS'ta hiç
                    // görünmüyordu. Artık iOS de bloğu atlıyor, mesaj çiziliyor.
                    let blockType = (try? container.decode(String.self, forKey: .type)) ?? ""

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
                    case "":
                        print("⚠️ [Paylisher] Block has no `type` - skipping block, message still shown")
                        self = .unknown("")
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

                // Image fit / position / inner inset — parity with Studio preview
                // + Android. nil defaults keep the legacy edge-to-edge cover.
                let imageFit: String?       // "cover" | "contain" | "fill"
                let imageAlignX: String?    // "left" | "center" | "right"
                let imageAlignY: String?    // "top" | "center" | "bottom"
                let imagePadding: Int?      // INNER inset percent (0–45)

                init(from decoder: Decoder) throws {

                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    self.type = try? container.decode(String.self, forKey: .type)

                    self.order = decodeIntOrString(container, forKey: .order)

                    self.url = try? container.decode(String.self, forKey: .url)
                    self.alt = try? container.decode(String.self, forKey: .alt)
                    self.link = try? container.decode(String.self, forKey: .link)

                    self.radius = decodeIntOrString(container, forKey: .radius)

                    self.margin = decodeIntOrString(container, forKey: .margin)

                    self.marginTop = decodeIntOrString(container, forKey: .marginTop)
                    self.marginBottom = decodeIntOrString(container, forKey: .marginBottom)

                    self.imageFit = try? container.decode(String.self, forKey: .imageFit)
                    self.imageAlignX = try? container.decode(String.self, forKey: .imageAlignX)
                    self.imageAlignY = try? container.decode(String.self, forKey: .imageAlignY)
                    self.imagePadding = decodeIntOrString(container, forKey: .imagePadding)
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

                    self.order = decodeIntOrString(container, forKey: .order)

                    self.verticalSpacing = decodeIntOrString(container, forKey: .verticalSpacing)

                    self.fillAvailableSpacing = decodeBoolOrString(container, forKey: .fillAvailableSpacing) ?? false

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

                    self.order = decodeIntOrString(container, forKey: .order)

                    self.content = try? container.decode([String: String].self, forKey: .content)
                    self.action = try? container.decode(String.self, forKey: .action)
                    self.fontFamily = try? container.decode(String.self, forKey: .fontFamily)
                    self.fontWeight = try? container.decode(String.self, forKey: .fontWeight)
                    self.fontSize = decodeStringOrInt(container, forKey: .fontSize)

                    self.underscore = decodeBoolOrString(container, forKey: .underscore) ?? false

                    self.italic = decodeBoolOrString(container, forKey: .italic) ?? false

                    self.color = try? container.decode(String.self, forKey: .color)
                    self.textAlignment = try? container.decode(String.self, forKey: .textAlignment)

                    self.horizontalMargin = decodeIntOrString(container, forKey: .horizontalMargin)

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
                        self.fontSize = decodeStringOrInt(container, forKey: .fontSize)
                        
                        self.underscore = decodeBoolOrString(container, forKey: .underscore) ?? false
                        
                        self.italic = decodeBoolOrString(container, forKey: .italic) ?? false
                        
                        self.textColor = try? container.decode(String.self, forKey: .textColor)
                        self.backgroundColor = try? container.decode(String.self, forKey: .backgroundColor)
                        self.borderColor = try? container.decode(String.self, forKey: .borderColor)
                        
                        self.borderRadius = decodeIntOrString(container, forKey: .borderRadius)
                        
                        self.horizontalSize = try? container.decode(String.self, forKey: .horizontalSize)
                        self.verticalSize = try? container.decode(String.self, forKey: .verticalSize)
                        self.buttonPosition = try? container.decode(String.self, forKey: .buttonPosition)
                        
                        self.margin = decodeIntOrString(container, forKey: .margin)
                        
                    }

                }

            }
        }
    }
}
