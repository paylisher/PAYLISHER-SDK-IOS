//
//  SilentPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 28.03.2025.
//

import Foundation

public class SilentPayload {
    
    public static let shared = SilentPayload()
    
    public init(){}
    
    public func silentPayload(userInfo: [AnyHashable: Any]) -> SilentNotification {
        
        let title = userInfo["title"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
        let imageUrl = userInfo["imageUrl"] as? String ?? ""
        let type = userInfo["type"] as? String ?? ""
        let silent = userInfo["silent"] as? String ?? ""
        let action = userInfo["action"] as? String ?? ""
        let displayTime = userInfo["displayTime"] as? String ?? ""
        
        let silentNotification = SilentNotification(title: title, message: message, type: type, action: action, silent: silent, imageUrl: imageUrl, displayTime: displayTime)
        
        return silentNotification
    }
}
