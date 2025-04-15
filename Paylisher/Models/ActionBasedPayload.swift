//
//  ActionBasedPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 19.03.2025.
//

import Foundation


public class ActionBasedPayload {
    
    public static let shared = ActionBasedPayload()
    
    public init(){}
    
    public func actionBasedPayload(userInfo: [AnyHashable: Any]) -> ActionBaseNotification {
    
        
        let title = userInfo["title"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
        let imageUrl = userInfo["imageUrl"] as? String ?? ""
        let type = userInfo["type"] as? String ?? ""
        let silent = userInfo["silent"] as? String ?? ""
        let action = userInfo["action"] as? String ?? ""
        let defaultLang = userInfo["defaultLang"] as? String ?? ""
        
        let condition: ActionBaseCondition = {
                    if let conditionString = userInfo["condition"] as? String,
                       let data = conditionString.data(using: .utf8) {
                        do {
                            if let conditionDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                               let displayTime = conditionDict["displayTime"] as? String {
                                return ActionBaseCondition(displayTime: displayTime)
                            }
                        } catch {
                            print("Error parsing condition JSON: \(error)")
                        }
                    }
                    // Varsayılan olarak boş bir displayTime atayabilirsiniz veya istediğiniz başka bir default değeri.
            return ActionBaseCondition(displayTime: "")
                }()
        
        let actionBasedNotification = ActionBaseNotification(title: title, message: message, imageUrl: imageUrl, type: type, silent: silent, action: action, defaultLang: defaultLang, condition: condition)
        
        return actionBasedNotification
        
    }
    
}


