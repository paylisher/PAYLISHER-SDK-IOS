//
//  NotificationService.swift
//  PaylisherNotificationServiceExtension
//
//  Created by Rasim Burak Kaya on 11.02.2025.
//

import MobileCoreServices
import UserNotifications
import Paylisher

class NotificationService: UNNotificationServiceExtension {
    

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) ->
            Void
    ) {

        self.contentHandler = contentHandler

        guard
            let bestAttemptContent = request.content.mutableCopy()
                as? UNMutableNotificationContent
        else {
            contentHandler(request.content)
            return
        }

        self.bestAttemptContent = bestAttemptContent

        let userInfo = bestAttemptContent.userInfo
        
        //print("userInfo: \(userInfo)")

        let type = userInfo["type"] as? String
        let defaultLang = userInfo["defaultLang"] as? String ?? "en"
        
        let action = userInfo["action"] as? String ?? ""

        
        let title = parseJSONString(
            userInfo["title"] as? String, language: defaultLang)
        let message = parseJSONString(
            userInfo["message"] as? String, language: defaultLang)

        let silent = userInfo["silent"] as? String
        let imageUrl = userInfo["imageUrl"] as? String ?? ""

        print("Notification Type: \(type)")
        print("Title: \(title)")
        print("Message: \(message)")
        print("Image URL: \(imageUrl) \n\n\n\n")
        
        bestAttemptContent.title = title
        bestAttemptContent.body = message

        if silent == "true" {
            bestAttemptContent.sound = nil
        } else {
            bestAttemptContent.sound = UNNotificationSound.default
        }
        
        if let imageUrlString = userInfo["imageUrl"] as? String,
           let imageUrl = URL(string: imageUrlString) {

            URLSession.shared.downloadTask(with: imageUrl) { localURL, response, error in
                print("Görsel İndirme Tamamlandı. localURL: \(String(describing: localURL)), error: \(String(describing: error))")

                if let localURL = localURL {
                    do {
                        let tempDirectory = FileManager.default.temporaryDirectory
                        let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")

                        try FileManager.default.moveItem(at: localURL, to: tempFileURL)

                        let attachmentOptions = [UNNotificationAttachmentOptionsTypeHintKey: kUTTypeJPEG] as [AnyHashable: Any]
                        let attachment = try UNNotificationAttachment(identifier: UUID().uuidString, url: tempFileURL, options: attachmentOptions)

                        bestAttemptContent.attachments = [attachment]

                    } catch {
                        print("Görsel ekleme hatası: \(error)")
                    }
                } else {
                    print("Görsel indirilemedi")
                }

                contentHandler(bestAttemptContent)
            }.resume()

        } else {
            print("Bildirim görselsiz gönderiliyor")
            contentHandler(bestAttemptContent)
        }
        let identifier = request.identifier
        CoreDataManager.shared.insertNotification(
            type: type ?? "UNKNOWN",
            receivedDate: Date(),
            expirationDate: Date().addingTimeInterval(120), // 2 dk sonra
            payload: userInfo.description,
            status: "UNREAD",
            identifier: identifier
        )
        print("Bildirim Core Data'ya kaydedildi!")
        
        let notifications = CoreDataManager.shared.fetchAllNotifications()
        print("Core Data'daki Bildirimler (\(notifications.count) kayıt var):")

        for notification in notifications {
            print("""
            ID: \(notification.id)
            Tür: \(notification.type)
            Alınma Tarihi: \(notification.receivedDate ?? Date())
            Durum: \(notification.status)
            İçerik: \(notification.payload ?? "Boş")
            Identifier: \(notification.notificationIdentifier)
            
            """)
        }

    }
  
    func parseJSONString(_ jsonString: String?, language: String?) -> String {
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

    override func serviceExtensionTimeWillExpire() {

        if let contentHandler = contentHandler,
            let bestAttemptContent = bestAttemptContent
        {
            contentHandler(bestAttemptContent)
        }
    }
}
