//
//  NotificationType.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 11.02.2025.
//

import Foundation

//public enum NotificationType: String {
//    
//    case push = "PUSH"
//    
//    case inApp = "IN-APP"
//    
//    case geofence = "GEOFENCE"
//    
//    case actionBased = "ACTION-BASED"
//     
//    
//    
//}

public enum NotificationType {
    case push
    case actionBased
    case geofence
    case inApp

    
    init?(rawValue: String) {
        switch rawValue {
        case "IN-APP":
            self = .inApp
        case "PUSH":
            self = .push
        case "ACTION-BASED":
            self = .actionBased
        case "GEOFENCE":
            self = .geofence
      
        default:
            return nil
        }
    }
}
