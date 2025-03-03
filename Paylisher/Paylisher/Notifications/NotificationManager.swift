//
//  NotificationManager.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 3.03.2025.
//

import Foundation
import UserNotifications
import UIKit
import CoreData
import MobileCoreServices

public class NotificationManager {
    
    public static let shared = NotificationManager()
    
    public func showNotification (
        with content: UNMutableNotificationContent,
        for request: UNNotificationRequest,
        completion: @escaping (UNNotificationContent) -> Void
    ) {
        let userInfo = content.userInfo
        
        // Parse data from userInfo
        let type = userInfo["type"] as? String ?? "UNKNOWN"
        let defaultLang = userInfo["defaultLang"] as? String ?? "en"
        let action = userInfo["action"] as? String ?? ""
        let title = parseJSONString(userInfo["title"] as? String, language: defaultLang)
        let message = parseJSONString(userInfo["message"] as? String, language: defaultLang)
        let silent = userInfo["silent"] as? String
        
        // Apply your logic to the content
        if silent == "true" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound.default
        }
        content.title = title
        content.body = message
        
        // Handle image attachments asynchronously
        if
            let imageUrlString = userInfo["imageUrl"] as? String,
            let imageUrl = URL(string: imageUrlString)
        {
            addImageAttachment(from: imageUrl, to: content) { updatedContent in
                // Once the image is fetched/attached, update Core Data
               // self.saveToCoreData(type: type, request: request, userInfo: userInfo)
                // Then call the completion with updated content
                completion(updatedContent)
            }
        } else {
            print("No image found; continuing without an image.")
            // Update Core Data before returning
           // saveToCoreData(type: type, request: request, userInfo: userInfo)
            completion(content)
        }
    }
    
    // MARK: - Core Data Saving Logic
    
 /*   private func saveToCoreData(
        type: String,
        request: UNNotificationRequest,
        userInfo: [AnyHashable : Any]
    ) {
        let identifier = request.identifier
        
        CoreDataManager.shared.insertNotification(
            type: type,
            receivedDate: Date(),
            expirationDate: Date().addingTimeInterval(120),
            payload: userInfo.description,
            status: "UNREAD",
            identifier: identifier
        )
        
        print("Notification saved to Core Data!")
        
        let notifications = CoreDataManager.shared.fetchAllNotifications()
        print("Core Data Notifications (\(notifications.count) records):")
        
        for notification in notifications {
            print("""
        ID: \(notification.id)
        Type: \(notification.type)
        Received Date: \(notification.receivedDate ?? Date())
        Status: \(notification.status)
        Payload: \(notification.payload ?? "Empty")
        Identifier: \(notification.notificationIdentifier)
        """)
        }
    }*/
    
    
    func addImageAttachment(from imageUrl: URL, to content: UNMutableNotificationContent, completion: @escaping (UNMutableNotificationContent) -> Void) {
        URLSession.shared.downloadTask(with: imageUrl) { localURL, response, error in
            print("Görsel İndirme Tamamlandı. localURL: \(String(describing: localURL)), error: \(String(describing: error))")
            
            if let localURL = localURL {
                do {
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let tempFileURL = tempDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    
                    try FileManager.default.moveItem(at: localURL, to: tempFileURL)
                    
                    let attachmentOptions = [UNNotificationAttachmentOptionsTypeHintKey: kUTTypeJPEG] as [AnyHashable: Any]
                    let attachment = try UNNotificationAttachment(identifier: UUID().uuidString, url: tempFileURL, options: attachmentOptions)
                    
                    content.attachments = [attachment]
                } catch {
                    print("Görsel ekleme hatası: \(error)")
                }
            } else {
                print("Görsel indirilemedi")
            }
            completion(content)
        }.resume()
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
    
}

