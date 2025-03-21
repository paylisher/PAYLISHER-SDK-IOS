//
//  PaylisherActionBaseNotification.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 12.02.2025.
//

import Foundation

public struct ActionBasedCondition {
    
    public let delay: Int
    
    public init(delay: Int) {
        
        self.delay = delay
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
    
    let condition: ActionBasedCondition
    
    public init(title: String, message: String, imageUrl: String, type: String, silent: String, action: String, defaultLang: String, condition: ActionBasedCondition) {
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
