//
//  PaylisherSilentNotification.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 28.03.2025.
//

import Foundation

public struct SilentNotification {
    
    let title: String
    
    let message: String
    
    let type: String
    
    let action: String
    
    let silent: String
    
    let imageUrl: String
    
    let displayTime: String?
    
    public init(title: String, message: String, type: String, action: String, silent: String, imageUrl: String, displayTime: String?) {
        self.title = title
        self.message = message
        self.type = type
        self.action = action
        self.silent = silent
        self.imageUrl = imageUrl
        self.displayTime = displayTime
    }
}
