//
//  PaylisherGeofenceNotification.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 12.02.2025.
//

import Foundation

public struct GeofenceNotification: Codable {
    
    let title: String?
    
    let message: String?
    
    let imageUrl: String?
    
    let type: String?
    
    let silent: String?
    
    let action: String?
    
    let defaultLang: String?
    
    let condition: Condition?
    
    let geofence: Geofence?
    
    public struct Condition: Codable {
        
        let displayTime: String?
        
       public init(from decoder: Decoder) throws {
            
        let container = try decoder.container(keyedBy: CodingKeys.self)
           
           self.displayTime = try? container.decode(String.self, forKey: .displayTime)
           
            
        }
        
    }
    
    public struct Geofence: Codable {
        
        let trigger: String?
        
        let geofenceId: String?
        
        let radius: String?
        
        let latitude: Double?
        
        let longitude: Double?
        
        public init(from decoder: Decoder) throws {
             
         let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.trigger = try? container.decode(String.self, forKey: .trigger)
            
            self.geofenceId = try? container.decode(String.self, forKey: .geofenceId)
            
            if let radiusAsDouble = try? container.decode(Double.self, forKey: .radius) {
                        // JSON'da numeric olarak gelmişse
                        self.radius = String(radiusAsDouble)
                    }
                    else if let radiusAsInteger = try? container.decode(Int.self, forKey: .radius) {
                        // JSON'da tam sayı olarak gelmişse
                        self.radius = String(radiusAsInteger)
                    }
                    else if let radiusAsString = try? container.decode(String.self, forKey: .radius) {
                        // JSON'da zaten string olarak gelmişse
                        self.radius = radiusAsString
                    }
                    else {
                        // Hiçbir formatta yoksa nil
                        self.radius = nil
                    }
            
            if let latStr = try? container.decode(String.self, forKey: .latitude),
                       let lat = Double(latStr) {
                        self.latitude = lat
                    } else {
                        self.latitude = try? container.decode(Double.self, forKey: .latitude)
                    }

                    if let lonStr = try? container.decode(String.self, forKey: .longitude),
                       let lon = Double(lonStr) {
                        self.longitude = lon
                    } else {
                        self.longitude = try? container.decode(Double.self, forKey: .longitude)
                    }
            
           /* if let latitudeStr = try? container.decode(String.self, forKey: .latitude),
               let doubleVal = Double(latitudeStr) {
                self.latitude = doubleVal
            } else {
                self.latitude = nil
            }
            
            if let longitudeStr = try? container.decode(String.self, forKey: .longitude),
               let doubleVal = Double(longitudeStr) {
                self.longitude = doubleVal
            } else {
                self.longitude = nil
            }*/
            
             
         }
    }
    
    public init(from decoder: Decoder) throws {
         
     let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.title = try? container.decode(String.self, forKey: .title)
        self.message = try? container.decode(String.self, forKey: .message)
        self.imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        self.type = try? container.decode(String.self, forKey: .type)
        self.silent = try? container.decode(String.self, forKey: .silent)
        self.action = try? container.decode(String.self, forKey: .action)
        self.defaultLang = try? container.decode(String.self, forKey: .defaultLang)
        
        self.condition = try? container.decode(GeofenceNotification.Condition.self, forKey: .condition)
        
        self.geofence = try? container.decode(GeofenceNotification.Geofence.self, forKey: .geofence)
    
     }
    
}
