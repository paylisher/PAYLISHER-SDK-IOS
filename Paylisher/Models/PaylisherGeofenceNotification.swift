//
//  PaylisherGeofenceNotification.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 12.02.2025.
//

import Foundation

public struct GeofenceCondition {
    public let displayTime: String?

    public init(displayTime: String?) {
        self.displayTime = displayTime
    }
}

public struct Geofence {
    
    public let trigger: String
    
    public let latitude: String
    
    public let longitude: String
    
    public let radius: String
    
    public let geofenceId: String
    
    public init(trigger: String, latitude: String, longitude: String, radius: String, geofenceId: String) {
        self.trigger = trigger
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.geofenceId = geofenceId
    }
}

public struct GeofenceNotification {
    
    let title: String
    
    let message: String
    
    let imageUrl: String
    
    let type: String
    
    let action: String
    
    let defaultLang: String
    
    let silent: String
    
    let condition: GeofenceCondition
    
    public init(title: String, message: String, imageUrl: String, type: String, action: String, defaultLang: String, silent: String, condition: GeofenceCondition) {
        self.title = title
        self.message = message
        self.imageUrl = imageUrl
        self.type = type
        self.action = action
        self.defaultLang = defaultLang
        self.silent = silent
        self.condition = condition
    }
}
