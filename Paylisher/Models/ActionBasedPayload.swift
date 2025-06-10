//
//  ActionBasedPayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 19.03.2025.
//

import Foundation


public class ActionBasedPayload {
    
    public static let shared = ActionBasedPayload()
    
    public init(){}
    
    public func actionBasedPayload(userInfo: [AnyHashable: Any]) -> ActionBaseNotification {
    
        
        let title = userInfo["title"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
        let imageUrl = userInfo["imageUrl"] as? String ?? ""
        let type = userInfo["type"] as? String ?? ""
        let silent = userInfo["silent"] as? String ?? ""
        let action = userInfo["action"] as? String ?? ""
        let defaultLang = userInfo["defaultLang"] as? String ?? ""
        
      /*  let condition: ActionBaseCondition = {
                    if let conditionString = userInfo["condition"] as? String,
                       let data = conditionString.data(using: .utf8) {
                        do {
                            if let conditionDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                               let displayTime = conditionDict["displayTime"] as? String,
                               let target = conditionDict["target"] as? String{
                                return ActionBaseCondition(displayTime: displayTime, target: target)
                            }
                        } catch {
                            print("Error parsing condition JSON: \(error)")
                        }
                    }
                    // Varsayılan olarak boş bir displayTime atayabilirsiniz veya istediğiniz başka bir default değeri.
            return ActionBaseCondition(displayTime: "", target: "")
                }()*/
        
        let condition: ActionBaseCondition = {
              let raw = userInfo["condition"]
              // 1️⃣ Eğer JSON-string gelmişse
              if let condStr = raw as? String,
                 let data    = condStr.data(using: .utf8),
                 let dict    = try? JSONSerialization.jsonObject(with: data) as? [String:Any]
              {
                  let dt     = dict["displayTime"] as? String
                  let tgt    = dict["target"] as? String ?? ""
                  return ActionBaseCondition(displayTime: dt, target: tgt)
              }
              // 2️⃣ Eğer doğrudan obje (Dictionary) gelmişse
              else if let dict = raw as? [AnyHashable:Any] {
                  // displayTime ya String ya Double olabileceği için her ikisini de deneyelim
                  let dt: String? = {
                      if let s = dict["displayTime"] as? String { return s }
                      if let d = dict["displayTime"] as? Double { return String(d) }
                      return nil
                  }()
                  let tgt = dict["target"] as? String ?? ""
                  return ActionBaseCondition(displayTime: dt, target: tgt)
              }
              // 3️⃣ Hiç condition yoksa ya da parse edilemediyse
              return ActionBaseCondition(displayTime: nil, target: "")
          }()
        
        let actionBasedNotification = ActionBaseNotification(title: title, message: message, imageUrl: imageUrl, type: type, silent: silent, action: action, defaultLang: defaultLang, condition: condition)
        
        return actionBasedNotification
        
    }
    
}


