//
//  PaylisherActionBaseNotification.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 12.02.2025.
//

import Foundation

public struct ActionBaseCondition {
    public let displayTime: String?

    public init(displayTime: String?) {
        self.displayTime = displayTime
    }
}

public struct ActionBaseNotification {
    
    let title: String
    
    let message: String
    
    let imageUrl: String
    
    let type: String
    
    let silent: String
    
    let action: String
    
    let defaultLang: String
    
    let condition: ActionBaseCondition
    
    public init(title: String, message: String, imageUrl: String, type: String, silent: String, action: String, defaultLang: String, condition: ActionBaseCondition) {
        self.title = title
        self.message = message
        self.imageUrl = imageUrl
        self.type = type
        self.silent = silent
        self.action = action
        self.defaultLang = defaultLang
        self.condition = condition
    }

}
