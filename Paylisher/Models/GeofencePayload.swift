//
//  GeofencePayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 19.03.2025.
//

import Foundation

public class GeofencePayload {
    
    public static let shared = GeofencePayload()
    
    public init(){}
    
    public func geofencePayload(userInfo: [AnyHashable: Any]) -> GeofenceNotification {
        
        let title = userInfo["title"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
        let imageUrl = userInfo["imageUrl"] as? String ?? ""
        let type = userInfo["type"] as? String ?? ""
        let silent = userInfo["silent"] as? String ?? ""
        let action = userInfo["action"] as? String ?? ""
        let defaultLang = userInfo["defaultLang"] as? String ?? ""
        
       let condition: GeofenceCondition = {
                    if let conditionString = userInfo["condition"] as? String,
                       let data = conditionString.data(using: .utf8) {
                        do {
                            if let conditionDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                               let displayTime = conditionDict["displayTime"] as? String {
                                return GeofenceCondition(displayTime: displayTime)
                            }
                        } catch {
                            print("Error parsing condition JSON: \(error)")
                        }
                    }
                    
            return GeofenceCondition(displayTime: "")
                }()
        
        /*  let geofence: Geofence = {
              guard let geoJSONString = userInfo["geofence"] as? String,
                    let data = geoJSONString.data(using: .utf8),
                    let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let trigger = dict["trigger"] as? String,
                    let lat        = dict["latitude"]  as? String,
                    let lon        = dict["longitude"] as? String,
                    let radius     = dict["radius"]    as? String,
                    let id         = dict["geofenceId"]as? String
                   
              else {
                  
                  return Geofence(trigger: "",
                                  latitude: "",
                                  longitude: "",
                                  radius: "",
                                  geofenceId: "")
              }
              return Geofence(trigger:    trigger,
                              latitude:   lat,
                              longitude:  lon,
                              radius:     radius,
                              geofenceId: id)
          }()*/

        
        let geofenceNotification = GeofenceNotification(title: title, message: message, imageUrl: imageUrl, type: type, action: action, defaultLang: defaultLang, silent: silent, condition: condition)
        
        return geofenceNotification
        
    }
    
}
