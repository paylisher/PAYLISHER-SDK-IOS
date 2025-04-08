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
      
        let title = userInfo["title"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
        let imageUrl = userInfo["imageUrl"] as? String ?? ""
        let typee = userInfo["type"] as? String ?? ""
        let silent = userInfo["silent"] as? String ?? ""
        let action = userInfo["action"] as? String ?? ""
        let defaultLang = userInfo["defaultLang"] as? String ?? ""
        
        let condition: PushCondition = {
                    if let conditionString = userInfo["condition"] as? String,
                       let data = conditionString.data(using: .utf8) {
                        do {
                            if let conditionDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                               let displayTime = conditionDict["displayTime"] as? String {
                                return PushCondition(displayTime: displayTime)
                            }
                        } catch {
                            print("Error parsing condition JSON: \(error)")
                        }
                    }
                    // Varsayılan olarak boş bir displayTime atayabilirsiniz veya istediğiniz başka bir default değeri.
            return PushCondition(displayTime: "")
                }()
        
        let pushNotification = PushNotification(title: title, message: message, imageUrl: imageUrl, type: typee, silent: silent, action: action, defaultLang: defaultLang, condition: condition)
        
           return pushNotification
      
    }

}
