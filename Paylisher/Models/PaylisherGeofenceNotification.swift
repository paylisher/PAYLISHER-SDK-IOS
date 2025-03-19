//
//  PaylisherGeofenceNotification.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 12.02.2025.
//

import Foundation

public struct GeofenceNotification {
    
    let title: String
    
    let message: String
    
    let imageUrl: String
    
    let type: String
    
    let action: String
    
    let defaultLang: String
    
    let silent: String
    
    //condition ve geofence'yi daha sonra ekle
    
    public init(title: String, message: String, imageUrl: String, type: String, action: String, defaultLang: String, silent: String) {
        self.title = title
        self.message = message
        self.imageUrl = imageUrl
        self.type = type
        self.action = action
        self.defaultLang = defaultLang
        self.silent = silent
    }
}
