//
//  UIColorHex.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 20.02.2025.
//

import UIKit

extension UIColor {
    
    convenience init?(hex: String) {
        var cleanedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanedHex.hasPrefix("#") {
            cleanedHex.removeFirst()
        } else if cleanedHex.hasPrefix("0X") {
            cleanedHex.removeSubrange(cleanedHex.startIndex..<cleanedHex.index(cleanedHex.startIndex, offsetBy: 2))
        }

        guard cleanedHex.count == 6 || cleanedHex.count == 8 else {
            return nil
        }
        
        var rgbValue: UInt64 = 0
        guard Scanner(string: cleanedHex).scanHexInt64(&rgbValue) else {
            return nil
        }
        
        if cleanedHex.count == 6 {
            let r = (rgbValue & 0xFF0000) >> 16
            let g = (rgbValue & 0x00FF00) >> 8
            let b = (rgbValue & 0x0000FF)
            self.init(
                red: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: 1.0
            )
        } else {
            let r = (rgbValue & 0xFF000000) >> 24
            let g = (rgbValue & 0x00FF0000) >> 16
            let b = (rgbValue & 0x0000FF00) >> 8
            let a = (rgbValue & 0x000000FF)
            self.init(
                red: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: CGFloat(a) / 255.0
            )
        }
    }
}

