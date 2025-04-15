//
//  CoreDataManager.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 11.02.2025.
//
import Foundation
import CoreData


public class CoreDataManager {
    
   public static let shared = CoreDataManager()

    var persistentContainer: NSPersistentContainer?
    private var appGroupIdentifier: String?
    
    public func configure(appGroupIdentifier: String) {
                self.appGroupIdentifier = appGroupIdentifier
        self.x()
            }
    
    private init(){}

    
        
       // let bundleIdentifier = "Paylisher_Paylisher"
       // let bundle = Bundle(identifier: bundleIdentifier)
    
    func x(){
        
        let bundle = Bundle(for: NotificationEntity.self)
        print("Bundle identifier: \(bundle.bundleIdentifier ?? "nil")")
        
        guard let appGroupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier!)
        else {
            fatalError("App Group URL bulunamadı.")
        }
        
        let storeURL = appGroupURL.appendingPathComponent("PaylisherDatabase.sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        
        /*  guard let modelURL = bundle.url(forResource: "PaylisherDatabase", withExtension: "momd"),
         let model = NSManagedObjectModel(contentsOf: modelURL) else {
         fatalError("Core Data modeli yüklenemedi.")
         }*/
        
        let model = CoreDataManager.createManagedObjectModel()
        print("Model programatik olarak oluşturuldu")
        
        print("Bundle path: \(bundle.bundlePath)")
        print("All bundle resources: \(bundle.paths(forResourcesOfType: "momd", inDirectory: nil))")
        print("Model entities: \(model.entities.map { $0.name ?? "unnamed" })")
        /* guard let modelURL = bundle.url(forResource: "PaylisherDatabase", withExtension: "momd"),
         let model = NSManagedObjectModel(contentsOf: modelURL) else {
         
         if let allModels = bundle.urls(forResourcesWithExtension: "momd", subdirectory: nil) {
         print("Available models: \(allModels)")
         } else {
         print("No models found in bundle")
         print("Bundle for type: \(bundle.bundlePath)")
         }
         
         fatalError("Core Data modeli yüklenemedi.")
         }*/
        
        persistentContainer = NSPersistentContainer(name: "PaylisherDatabase", managedObjectModel: model)
        persistentContainer?.persistentStoreDescriptions = [storeDescription]
        
        persistentContainer?.loadPersistentStores { _, error in
            if let error = error {
                print("CoreData yüklenirken hata oluştu: \(error)")
                print("Store URL: \(storeDescription.url?.absoluteString ?? "nil")")
                fatalError("Core Data yüklenirken hata oluştu: \(error.localizedDescription)")
            }else{
                print("CoreData başarıyla yüklendi")
            }
        }
    }
    
    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        
        let notificationEntity = NSEntityDescription()
        notificationEntity.name = "NotificationEntity"
        notificationEntity.managedObjectClassName = "NotificationEntity"
      /*  if isExample {
                notificationEntity.managedObjectClassName = "NotificationEntity"
            } else {
                notificationEntity.managedObjectClassName = "Paylisher.NotificationEntity"
            }*/
        
       
        var properties: [NSPropertyDescription] = []
        
        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .integer64AttributeType
        id.isOptional = false
        properties.append(id)
        
        let payload = NSAttributeDescription()
        payload.name = "payload"
        payload.attributeType = .stringAttributeType
        payload.isOptional = true
        properties.append(payload)
        
        let status = NSAttributeDescription()
        status.name = "status"
        status.attributeType = .stringAttributeType
        status.isOptional = true
        properties.append(status)
        
        let type = NSAttributeDescription()
        type.name = "type"
        type.attributeType = .stringAttributeType
        type.isOptional = true
        properties.append(type)
        
        let gcmMessageID = NSAttributeDescription()
        gcmMessageID.name = "gcmMessageID"
        gcmMessageID.attributeType = .stringAttributeType
        gcmMessageID.isOptional = true
        properties.append(gcmMessageID)
        
        let receivedDate = NSAttributeDescription()
        receivedDate.name = "receivedDate"
        receivedDate.attributeType = .dateAttributeType
        receivedDate.isOptional = true
        properties.append(receivedDate)
        
        let expirationDate = NSAttributeDescription()
        expirationDate.name = "expirationDate"
        expirationDate.attributeType = .dateAttributeType
        expirationDate.isOptional = true
        properties.append(expirationDate)
        
        
        
        notificationEntity.properties = properties
        model.entities = [notificationEntity]
        
        return model
    }

    var context: NSManagedObjectContext {
        
        guard let container = persistentContainer else {
                       fatalError("Persistent container henüz oluşturulmadı")
                   }
                   return container.viewContext
    }

   public func saveContext() {
       let context = persistentContainer?.viewContext
       if ((context?.hasChanges) != nil) {
            do {
                try context?.save()
            } catch {
                print("Veri kaydedilirken hata oluştu: \(error)")
            }
        }
    }

    
   public func generateNewID() -> Int64 {
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

    
    public func insertNotification(type: String, receivedDate: Date, expirationDate: Date, payload: String, status: String, gcmMessageID: String) {
        let context = (persistentContainer?.viewContext)!
        let notification = NotificationEntity(context: context)
        notification.id = generateNewID()
        notification.type = type
        notification.receivedDate = receivedDate
        notification.expirationDate = expirationDate
        notification.payload = payload
        notification.status = status
        //notification.gcmMessageID = gcmMessageID

        saveContext()
    }

    
   public func fetchAllNotifications() -> [NotificationEntity] {
        let fetchRequest: NSFetchRequest<NotificationEntity> = NotificationEntity.fetchRequest() as! NSFetchRequest<NotificationEntity>
       
       // Filter for notifications with status "UNREAD"
      // fetchRequest.predicate = NSPredicate(format: "status == %@", "UNREAD")
       
       do {
           return try context.fetch(fetchRequest)
       } catch {
           return []
       }
    }

    
   public func updateNotificationStatus(byMessageID gcmMessageID: String, newStatus: String) {
     
        let fetchRequest: NSFetchRequest<NotificationEntity> = NotificationEntity.fetchRequest() as! NSFetchRequest<NotificationEntity>
       fetchRequest.predicate = NSPredicate(format: "gcmMessageID == %@", gcmMessageID)
      
        
        
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
    
   public func notificationExists(withMessageID gcmMessageID: String) -> Bool {
        let fetchRequest: NSFetchRequest<NotificationEntity> = NotificationEntity.fetchRequest() as! NSFetchRequest<NotificationEntity>
        fetchRequest.predicate = NSPredicate(format: "gcmMessageID == %@", gcmMessageID)
    

        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Hata: Core Data'da kayıt kontrol edilirken bir hata oluştu: \(error)")
            return false
        }
    }



    
   public func deleteAllNotifications() {
        
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
