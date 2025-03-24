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
        
        

        
        let pushNotification = PushNotification(title: title, message: message, imageUrl: imageUrl, type: typee, silent: silent, action: action, defaultLang: defaultLang)
        
        
        
           return pushNotification
           
        
    }

}
