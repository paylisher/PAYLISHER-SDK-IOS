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
import Paylisher

 
public class NotificationManager {
     
    public static let shared = NotificationManager()
    private var isProcessingFromExtension = false
    
    
    
    private func showNotification(_ userInfo: [AnyHashable : Any], _ content: UNMutableNotificationContent, _ request: UNNotificationRequest, _ completion: @escaping (UNNotificationContent) -> Void) {
        let pushNotification = PushPayload.shared.pushPayload(userInfo: userInfo)
        
        let defaultLang = pushNotification.defaultLang
        let localizedTitle = parseJSONString(pushNotification.title, language: defaultLang)
        let localizedMessage = parseJSONString(pushNotification.message, language: defaultLang)
        let action = pushNotification.action
        let silent = pushNotification.silent
        let imageUrll = pushNotification.imageUrl
        let type = pushNotification.type
        
        
        if silent == "true" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound.default
        }
        
        content.title = localizedTitle
        content.body = localizedMessage
        
        // Görsel ekleme işlemi
        if let imageUrl = URL(string: imageUrll ) {
            addImageAttachment(from: imageUrl, to: content) { updatedContent in
                
                DispatchQueue.global(qos: .background).async {
                    self.saveToCoreData(type: type, request: request, userInfo: userInfo)
                }
                
               completion(updatedContent)
            }
        } else {
            print("No image found; continuing without an image.")
            
            DispatchQueue.global(qos: .background).async {
                self.saveToCoreData(type: type, request: request, userInfo: userInfo)
            }
            
            completion(content)
        }
    }
    
    public func customNotification(windowScene: UIWindowScene?, userInfo: [AnyHashable : Any], _ content: UNMutableNotificationContent, _ request: UNNotificationRequest, _ completion: @escaping (UNNotificationContent) -> Void){
        
//        print("customNotification userInfo \(userInfo)" )
        // Check the source condition first
        if let source = userInfo["source"] as? String, source == "Paylisher" {
            
//            print("customNotification source string: \(source)")
            
           
            
            // Get the type as String first, then convert it
            if let typeString = userInfo["type"] as? String {
//                print("customNotification type string: \(typeString)")
                let notificationType = NotificationType(rawValue: typeString)
                
                
                
                print("customNotification type string: \(notificationType)")
                switch notificationType {
                case .push:
                    print("FCM customNotification push")
                    
                   // showNotification(userInfo, content, request, completion)
                    
                    showNotification(userInfo, content, request) { updatedContent in
                                        // Extension'da mı yoksa willPresent'te mi çalışıyoruz?
                                        if windowScene == nil {
                                            // Extension'da çalışıyoruz, veritabanına kaydet
                                            DispatchQueue.global(qos: .background).async {
                                                self.saveToCoreData(type: typeString, request: request, userInfo: userInfo)
                                            }
                                        } else {
                                            // willPresent'te çalışıyoruz, sadece göster kaydetme
                                            print("Notification already saved in extension, skipping database save")
                                        }
                                        completion(updatedContent)
                                    }
                                        
                    
                case .actionBased:
                    // Handle action based notification
                    // TODO: conditions
                    break
                case .geofence:
                    // Handle geofence notification
                    break
                case .inApp:
                    // Handle in-app notification
                    
                    print("FCM customNotification inApp")
                    
                    PaylisherNativeInAppNotificationManager.shared.nativeInAppNotification(userInfo: userInfo, windowScene: windowScene)
                    PaylisherCustomInAppNotificationManager.shared.parseInAppPayload(from: userInfo, windowScene: windowScene)
                    PaylisherCustomInAppNotificationManager.shared.customInAppFunction(userInfo: userInfo, windowScene: windowScene)
                    
                    break
                case .none:
                    break
                }
            }
        }

    }
    
    public func customNotification(
        windowScene: UIWindowScene?,
        with content: UNMutableNotificationContent,
        for request: UNNotificationRequest,
        completion: @escaping (UNNotificationContent) -> Void
    ) {
        let userInfo = content.userInfo
        
        // customNotification(userInfo: userInfo, content, request, completion)
        customNotification(windowScene: windowScene, userInfo: userInfo, content, request) { _completion in
            completion(_completion)
        }
    }
    
    public func processNotificationFromExtension(userInfo: [AnyHashable: Any], content: UNMutableNotificationContent, request: UNNotificationRequest, completion: @escaping (UNNotificationContent) -> Void) {
        isProcessingFromExtension = true
        // Görseli ve içeriği özelleştir
        self.customNotification(windowScene: nil, userInfo: userInfo, content, request) { updatedContent in
            self.isProcessingFromExtension = false
            completion(updatedContent)
        }
    }
    
    public func processNotificationInForeground(windowScene: UIWindowScene?, userInfo: [AnyHashable: Any], content: UNMutableNotificationContent, request: UNNotificationRequest, completion: @escaping (UNNotificationContent) -> Void) {
        // Sadece in-app mesajları işleyin, push bildirimleri extension'da işlenmiş olmalı
        if let typeString = userInfo["type"] as? String, typeString == "inApp" {
            self.customNotification(windowScene: windowScene, userInfo: userInfo, content, request, completion)
        } else {
            // Push bildirimi - zaten extension'da işlenmiş olmalı
            completion(content)
        }
    }

   
   
    public func saveToCoreData(
        type: String,
        request: UNNotificationRequest,
        userInfo: [AnyHashable : Any]
    ) {
        let identifier = request.identifier
        print("saveToCoreData CALLED -> type: \(type), identifier: \(identifier)")
        
        if isProcessingFromExtension || type == "inApp" {
            
            if !CoreDataManager.shared.notificationExists(withIdentifier: identifier){
                print("saveToCoreData -> RECORD NOT FOUND -> inserting to DB")
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
                
                
            }else{
                print("saveToCoreData -> RECORD ALREADY EXISTS -> skipping insert")
            }
            
        }
        
        
        
        
        
        
    }
    
    
  public func addImageAttachment(from imageUrl: URL, to content: UNMutableNotificationContent, completion: @escaping (UNMutableNotificationContent) -> Void) {
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
    
  public func parseJSONString(_ jsonString: String?, language: String?) -> String {
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

