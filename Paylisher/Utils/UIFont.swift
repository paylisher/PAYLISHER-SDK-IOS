//
//  UIFont.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 21.05.2025.
//
import UIKit

/// 1) Font ailesi
enum FontFamily: String {
    case monospace
    case cursive
    case sansSerif = "sans-serif"
    
    /// UIFont’a çevirme
    func toUIFont(size: CGFloat, weight: UIFont.Weight, isItalic: Bool) -> UIFont {
        let base: UIFont
        switch self {
        case .monospace:
            base = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .cursive:
            // Sistemde yüklü örnek bir cursive
            base = UIFont(name: "SnellRoundhand", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        case .sansSerif:
            base = UIFont.systemFont(ofSize: size, weight: weight)
        }
        var traits = UIFontDescriptor.SymbolicTraits()
            if isItalic {
                traits.insert(.traitItalic)
            }
            // System font’ta bold weight zaten bold, ama cursive’da eklememiz gerekebilir:
            if weight == .bold {
                traits.insert(.traitBold)
            }
            
            // 3) Trait’leri uygula
            if !traits.isEmpty,
               let desc = base.fontDescriptor.withSymbolicTraits(traits) {
                return UIFont(descriptor: desc, size: size)
            }
            
            return base
        }
    }

/// 2) Font ağırlığı ve italik bilgisi
enum FontWeightModel: String {
    case regular
    case bold
    
    init(from string: String?) {
        switch string?.lowercased() {
        case "bold":
            self = .bold
        default:
            self = .regular
        }
    }
    
    var uiWeight: UIFont.Weight {
        switch self {
        case .bold:   return .bold
        case .regular:return .regular
        }
    }
}

/// 3) Font modelini tutan struct
struct FontModel {
    let family: FontFamily
    let weight:  FontWeightModel
    let size: CGFloat
    let isItalic: Bool
    let isUnderlined: Bool
  
    init?(family familyString: String?,
          weight weightString: String?,
          size sizeString: String?,
          italic italicBool: Bool?,
          underline underlineBool: Bool?) {
        // 1) family
        guard let fam = familyString?.lowercased(),
              let family = FontFamily(rawValue: fam)
        else { return nil }
        self.family = family
        
        // 2) weight
        self.weight = FontWeightModel(from: weightString)
        
        // 3) size: "14px" → 14.0
        guard let px = sizeString?
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "px", with: ""),
              let floatVal = Float(px)
        else { return nil }
        self.size = CGFloat(floatVal)
        
        // italic
        self.isItalic = italicBool ?? false
        self.isUnderlined = underlineBool ?? false
    }
    
    /// UIButton veya UILabel’a uygulamak için
    var uiFont: UIFont {
            family.toUIFont(size: size,
                            weight: weight.uiWeight,
                            isItalic: isItalic)
        }
    
    func attributedString(_ text: String) -> NSAttributedString {
         var attrs: [NSAttributedString.Key: Any] = [
             .font: uiFont
         ]
         if isUnderlined {
             attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
         }
         return NSAttributedString(string: text, attributes: attrs)
     }
}


