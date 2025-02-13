//
//  PaylisherGeofenceNotification.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 12.02.2025.
//

import Foundation

public struct GeofenceNotification {
    
    let title: String
    
    let body: String
    
    let imageUrl: String
    
    let type: String
    
    let action: String
    
    let defaultLang: String
    
    //condition ve geofence'yi daha sonra ekle
    
    public init(title: String, body: String, imageUrl: String, type: String, action: String, defaultLang: String) {
        self.title = title
        self.body = body
        self.imageUrl = imageUrl
        self.type = type
        self.action = action
        self.defaultLang = defaultLang
    }
}
