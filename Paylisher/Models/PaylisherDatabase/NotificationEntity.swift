//
//  NotificationEntity.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 11.02.2025.
//

import Foundation
import CoreData

@objc(NotificationEntity)
public class NotificationEntity: NSManagedObject {
    
    @NSManaged public var id: Int64
    
    @NSManaged public var type: String?
    
    @NSManaged public var receivedDate: Date?
    
    @NSManaged public var expirationDate: Date?
    
    @NSManaged public var payload: String?
    
    @NSManaged public var status: String?
    
    @NSManaged public var notificationIdentifier: String
    
  
}
