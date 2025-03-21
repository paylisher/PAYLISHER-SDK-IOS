//
//  PushPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.03.2025.
//

import Foundation
import Paylisher

public class PushPayload {
    
    public static let shared = PushPayload()
    
    public init() {
        
    }
  
    public func pushPayload(userInfo: [AnyHashable: Any]) -> PushNotification {
        
        var delay: Int = 0

        if let conditionString = userInfo["condition"] as? String,
           !conditionString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let data = conditionString.data(using: .utf8),
           let conditionDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           !conditionDict.isEmpty,
           let parsedDelay = conditionDict["delay"] as? Int {
            delay = parsedDelay
        } else {
            print("Delay verisi alınamadı, varsayılan değeri kullanıyorum.")
            delay = 0  
        }
    
        let title = userInfo["title"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
        let imageUrl = userInfo["imageUrl"] as? String ?? ""
        let typee = userInfo["type"] as? String ?? ""
        let silent = userInfo["silent"] as? String ?? ""
        let action = userInfo["action"] as? String ?? ""
        let defaultLang = userInfo["defaultLang"] as? String ?? ""
        
        

        
        let pushNotification = PushNotification(title: title, message: message, imageUrl: imageUrl, type: typee, silent: silent, action: action, defaultLang: defaultLang, delay: delay)
        
        
        
           return pushNotification
           
        
    }

}
