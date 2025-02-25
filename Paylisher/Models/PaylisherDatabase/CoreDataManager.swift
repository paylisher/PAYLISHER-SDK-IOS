//
//  CoreDataManager.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 11.02.2025.
//

import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()

    let persistentContainer: NSPersistentContainer

    public init() {
        
        guard let appGroupURL = FileManager.default
                   .containerURL(forSecurityApplicationGroupIdentifier: "group.com.paylisher.PaylisherExamplee")
               else {
                   fatalError("App Group URL bulunamadı.")
               }
        
        let storeURL = appGroupURL.appendingPathComponent("PaylisherDatabase.sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        
        persistentContainer = NSPersistentContainer(name: "PaylisherDatabase")
        persistentContainer.persistentStoreDescriptions = [storeDescription]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data yüklenirken hata oluştu: \(error.localizedDescription)")
            }
        }
    }

    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Veri kaydedilirken hata oluştu: \(error)")
            }
        }
    }

    
    func generateNewID() -> Int64 {
        //let fetchRequest: NSFetchRequest<NotificationEntity> = NotificationEntity.fetchRequest()
        let fetchRequest: NSFetchRequest<NotificationEntity> = NotificationEntity.fetchRequest() as! NSFetchRequest<NotificationEntity>

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        fetchRequest.fetchLimit = 1

        do {
            let lastEntity = try context.fetch(fetchRequest).first
            return (lastEntity?.id ?? 0) + 1
        } catch {
            return 1
        }
    }

    
    public func insertNotification(type: String, receivedDate: Date, expirationDate: Date, payload: String, status: String, identifier: String) {
        let context = persistentContainer.viewContext
        let notification = NotificationEntity(context: context)
        notification.id = generateNewID()
        notification.type = type
        notification.receivedDate = receivedDate
        notification.expirationDate = expirationDate
        notification.payload = payload
        notification.status = status
        notification.notificationIdentifier = identifier

        saveContext()
    }

    
    func fetchAllNotifications() -> [NotificationEntity] {
        let fetchRequest: NSFetchRequest<NotificationEntity> = NotificationEntity.fetchRequest() as! NSFetchRequest<NotificationEntity>
        do {
            return try context.fetch(fetchRequest)
        } catch {
            return []
        }
    }

    
    func updateNotificationStatus(byIdentifier identifier: String, newStatus: String) {
        let fetchRequest: NSFetchRequest<NotificationEntity> = NotificationEntity.fetchRequest() as! NSFetchRequest<NotificationEntity>
        fetchRequest.predicate = NSPredicate(format: "notificationIdentifier == %@", identifier)
        
        do {
            let notifications = try context.fetch(fetchRequest)
            if let notification = notifications.first {
                notification.status = newStatus
                saveContext()
            }
        } catch {
            print("Güncelleme hatası: \(error)")
        }
    }
    
    func notificationExists(withIdentifier identifier: String) -> Bool {
        let fetchRequest: NSFetchRequest<NotificationEntity> = NotificationEntity.fetchRequest() as! NSFetchRequest<NotificationEntity>
        fetchRequest.predicate = NSPredicate(format: "notificationIdentifier == %@", identifier)

        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Hata: Core Data'da kayıt kontrol edilirken bir hata oluştu: \(error)")
            return false
        }
    }



    
    func deleteAllNotifications() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NotificationEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
            saveContext()
        } catch {
            print("Silme hatası: \(error)")
        }
    }
}
