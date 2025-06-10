//
//  GeofencePayload.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 19.03.2025.
//

import Foundation
import Paylisher

public class GeofencePayload {
    
    public static let shared = GeofencePayload()
    
    public init(){}
    
    public func parseGeofenceNotification(
        from userInfo: [AnyHashable: Any]) -> GeofenceNotification? {
        
        // 1. Cast incoming push payload to [String:Any]
        guard let stringKeyedInfo = userInfo as? [String: Any] else {
            print("⚠️ userInfo'u [String:Any] olarak cast edemedim.")
            return nil
        }
        
        // 2. Normalize any JSON‐in‐String fields (e.g. "condition", "geofence")
        var normalizedInfo = [String: Any]()
        for (key, value) in stringKeyedInfo {
            switch key {
            case "condition", "geofence":
                // If the value is a JSON string, decode it into a dictionary
                if let jsonString = value as? String,
                   let data = jsonString.data(using: .utf8) {
                    do {
                        if let dict = try JSONSerialization
                            .jsonObject(with: data, options: []) as? [String: Any] {
                            normalizedInfo[key] = dict
                        } else {
                            print("ℹ️ '\(key)' bir JSON string ama [String:Any] olarak parse edilemedi.")
                            normalizedInfo[key] = value
                        }
                    } catch {
                        print("❌ '\(key)' JSON parse hatası:", error)
                        normalizedInfo[key] = value
                    }
                } else {
                    // Already a dictionary (or other type), pass through
                    normalizedInfo[key] = value
                }
            default:
                // Other keys (title, message, etc.)—pass through unchanged
                normalizedInfo[key] = value
            }
        }
        
        // 3. Serialize normalizedInfo back to Data
        do {
            let data = try JSONSerialization.data(withJSONObject: normalizedInfo, options: [])
            let decoder = JSONDecoder()
            // 4. Decode into your GeofenceNotification model
            let notification = try decoder.decode(GeofenceNotification.self, from: data)
            return notification
            
        } catch {
            print("❌ GeofenceNotification decode error:", error)
            return nil
        }
    }
    
    public func geofenceNotification(userInfo: [AnyHashable: Any]) {
        
        guard let payload = parseGeofenceNotification(from: userInfo) else {
            print("Payload parse edilemedi.")
            return
        }
        
        
        
    }

        
    
    
}
