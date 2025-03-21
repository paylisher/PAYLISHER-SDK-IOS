//
//  PaylisherPushNotification.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 12.02.2025.
//

import Foundation

/*public struct PushNotificationCondition {
    
    public let delay: Int
    
    public init(delay: Int) {
        
        self.delay = delay
    }
}*/

public struct PushNotification {
    
    let title: String
    
    let message: String
    
    let imageUrl: String
    
    let type: String
    
    let silent: String
    
    let action: String
    
    let defaultLang: String
    
    let delay: Int
    
    
    public init(title: String, message: String, imageUrl: String, type: String, silent: String, action: String, defaultLang: String, delay: Int) {
        self.title = title
        self.message = message
        self.imageUrl = imageUrl
        self.type = type
        self.silent = silent
        self.action = action
        self.defaultLang = defaultLang
        self.delay = delay
    }
    
}
