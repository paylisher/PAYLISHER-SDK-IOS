//
//  ActionBasedPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 19.03.2025.
//

import Foundation
import Paylisher

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
        
        let actionBasedNotification = ActionBaseNotification(title: title, message: message, imageUrl: imageUrl, type: type, silent: silent, action: action, defaultLang: defaultLang)
        
        return actionBasedNotification
        
    }
    
}


