//
//  PaylisherSilentNotification.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 12.05.2025.
//

import Foundation

public struct SilentNotification {
    
    let title: String
    
    let message: String
    
    let imageUrl: String
    
    let type: String
    
    let silent: String
    
    let action: String
    
    let defaultLang: String
    

    public init(title: String, message: String, imageUrl: String, type: String, silent: String, action: String, defaultLang: String) {
        self.title = title
        self.message = message
        self.imageUrl = imageUrl
        self.type = type
        self.silent = silent
        self.action = action
        self.defaultLang = defaultLang
    }
    
}
