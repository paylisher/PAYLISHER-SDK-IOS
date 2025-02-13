//
//  PaylisherActionBaseNotification.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 12.02.2025.
//

import Foundation

public struct ActionBaseNotification {
    
    let title: String
    
    let body: String
    
    let imageUrl: String
    
    let type: String
    
    let silent: Bool
    
    let action: String
    
    let defaultLang: String
    
    //condition kısmını daha sonra ekle
    
    public init(title: String, body: String, imageUrl: String, type: String, silent: Bool, action: String, defaultLang: String) {
        self.title = title
        self.body = body
        self.imageUrl = imageUrl
        self.type = type
        self.silent = silent
        self.action = action
        self.defaultLang = defaultLang
    }

}
