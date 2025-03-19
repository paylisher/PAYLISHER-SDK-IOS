//
//  GeofencePayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 19.03.2025.
//

import Foundation
import Paylisher

public class GeofencePayload {
    
    public static let shared = GeofencePayload()
    
    public init(){}
    
    public func geofencePayload(userInfo: [AnyHashable: Any]) -> GeofenceNotification {
        
        let title = userInfo["title"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
        let imageUrl = userInfo["imageUrl"] as? String ?? ""
        let type = userInfo["type"] as? String ?? ""
        let silent = userInfo["silent"] as? String ?? ""
        let action = userInfo["action"] as? String ?? ""
        let defaultLang = userInfo["defaultLang"] as? String ?? ""
        
        let geofenceNotification = GeofenceNotification(title: title, message: message, imageUrl: imageUrl, type: type, action: action, defaultLang: defaultLang, silent: silent)
        
        return geofenceNotification
        
    }
    
}
