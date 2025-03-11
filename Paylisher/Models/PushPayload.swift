//
//  PushPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.03.2025.
//

import Foundation
import UIKit
//import Paylisher

public class PushPayload {
    
    public static let shared = PushPayload()
    
    public init() {
    }
    
    
    
    public func pushPayload(userInfo: [AnyHashable: Any]) -> PushNotification {
    
        let title = userInfo["title"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
                 let imageUrl = userInfo["imageUrl"] as? String ?? ""
                 let type = userInfo["type"] as? String ?? ""
                 let silent = userInfo["silent"] as? String ?? ""
                 let action = userInfo["action"] as? String ?? ""
                 let defaultLang = userInfo["defaultLang"] as? String ?? ""
        
        let pushNotification = PushNotification(title: title, message: message, imageUrl: imageUrl, type: type, silent: silent, action: action, defaultLang: defaultLang)
           
           return pushNotification
           
        
    }
   
    public func parseJSONString(_ jsonString: String?, language: String?) -> String {
         guard let jsonString = jsonString,
               let jsonData = jsonString.data(using: .utf8) else {
             return "Unknown"
         }
         
         do {
             
             if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String] {
                 
                 if let language = language, let localizedText = jsonDict[language] {
                     return localizedText
                 }
                 
                 
                 if let firstValue = jsonDict.values.first {
                     return firstValue
                 }
             }
         } catch {
             print("JSON Parsing Error: \(error)")
         }
         
         return jsonString
     }
    
    
    
}
