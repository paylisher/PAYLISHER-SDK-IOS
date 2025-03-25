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
     
    
    private func pushNotification(_ userInfo: [AnyHashable : Any], _ content: UNMutableNotificationContent, _ request: UNNotificationRequest, _ completion: @escaping (UNNotificationContent) -> Void) {
        let pushNotification = PushPayload.shared.pushPayload(userInfo: userInfo)
        
        let defaultLang = pushNotification.defaultLang
        let localizedTitle = parseJSONString(pushNotification.title, language: defaultLang)
        let localizedMessage = parseJSONString(pushNotification.message, language: defaultLang)
        let action = pushNotification.action
        let silent = pushNotification.silent
        let imageUrl = pushNotification.imageUrl
        let type = pushNotification.type
        
        
        
        if silent == "true" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound.default
        }
        
        content.title = localizedTitle
        content.body = localizedMessage
        
        
        // Görsel ekleme işlemi
        if let imageUrl = URL(string: imageUrl ) {
            addImageAttachment(from: imageUrl, to: content) { updatedContent in
                
               DispatchQueue.global(qos: .background).async {
                    self.saveToCoreData(type: type, request: request, userInfo: userInfo)
                }
                
               completion(updatedContent)
                
               // self.handleNotificationDisplay(updatedContent, request: request, userInfo: userInfo, type: type, delay: delay, completion: completion)
            }
        } else {
            print("No image found; continuing without an image.")
            
           // self.handleNotificationDisplay(content, request: request, userInfo: userInfo, type: type, delay: delay, completion: completion)
            
            DispatchQueue.global(qos: .background).async {
                self.saveToCoreData(type: type, request: request, userInfo: userInfo)
            }
            
            completion(content)
        }
    }
    
    private func actionBasedNotification(_ userInfo: [AnyHashable : Any], _ content: UNMutableNotificationContent, _ request: UNNotificationRequest, _ completion: @escaping (UNNotificationContent) -> Void) {
        
        let actionBasedNotification = ActionBasedPayload.shared.actionBasedPayload(userInfo: userInfo)
        
        let defaultLang = actionBasedNotification.defaultLang
        let title = parseJSONString(actionBasedNotification.title, language: defaultLang)
        let message = parseJSONString(actionBasedNotification.message, language: defaultLang)
        let action = actionBasedNotification.action
        let silent = actionBasedNotification.silent
        let imageUrl = actionBasedNotification.imageUrl
        let type = actionBasedNotification.type
        let displayTime = actionBasedNotification.condition.displayTime
        //let delayMinutes = actionBasedNotification.condition.delay
        
        print("Display Time: \(displayTime)")
        
        if silent == "true" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound.default
        }
        
        content.title = title
        content.body = message
        
        
        if let imageUrl = URL(string: imageUrl ) {
            addImageAttachment(from: imageUrl, to: content) { updatedContent in
            
               /* self.NotificationDisplay(with: updatedContent,
                                                           request: request,
                                                           userInfo: userInfo,
                                                           type: type,
                                               delayMinutes: delayMinutes,
                                                           completion: completion)*/
        
                
                DispatchQueue.global(qos: .background).async {
                    self.saveToCoreData(type: type, request: request, userInfo: userInfo)
                }
                
               completion(updatedContent)
            }
        } else {
            print("No image found; continuing without an image.")
            
            /*self.NotificationDisplay(with: content,
                                                       request: request,
                                                       userInfo: userInfo,
                                                       type: type,
                                           delayMinutes: delayMinutes,
                                                       completion: completion)*/
            
           DispatchQueue.global(qos: .background).async {
                self.saveToCoreData(type: type, request: request, userInfo: userInfo)
            }
            
            completion(content)
        }
    }
    
    private func geofenceNotification(_ userInfo: [AnyHashable : Any], _ content: UNMutableNotificationContent, _ request: UNNotificationRequest, _ completion: @escaping (UNNotificationContent) -> Void) {
        
        let geofenceNotification = GeofencePayload.shared.geofencePayload(userInfo: userInfo)
        
        let defaultLang = geofenceNotification.defaultLang
        let title = parseJSONString(geofenceNotification.title, language: defaultLang)
        let message = parseJSONString(geofenceNotification.message, language: defaultLang)
        let action = geofenceNotification.action
        let silent = geofenceNotification.silent
        let imageUrl = geofenceNotification.imageUrl
        let type = geofenceNotification.type
        
        
        if silent == "true" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound.default
        }
        
        content.title = title
        content.body = message
        
        if let imageUrl = URL(string: imageUrl ) {
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
    
  
   /* private func NotificationDisplay(with updatedContent: UNMutableNotificationContent,
                                             request: UNNotificationRequest,
                                             userInfo: [AnyHashable: Any],
                                             type: String,
                                             delayMinutes: Int,
                                             completion: @escaping (UNNotificationContent) -> Void) {
        // Veritabanına kaydı duplicate kontrolüyle yapıyoruz:
        DispatchQueue.global(qos: .background).async {
            self.saveToCoreData(type: type, request: request, userInfo: userInfo)
        }
        
        
        // Eğer delay > 0 ise, bildirimin gösterimini geciktirmek için yeni bir yerel bildirim planlayın.
        if delayMinutes > 0 {
            let delaySeconds = TimeInterval(delayMinutes * 60)

            completion(UNMutableNotificationContent())

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)

            let localRequest = UNNotificationRequest(identifier: request.identifier, content: updatedContent, trigger: trigger)
            
            UNUserNotificationCenter.current().add(localRequest) { error in
                if let error = error {
                    print("Local notification scheduling error: \(error)")
                } else {
                    print("Local notification scheduled with delay of \(delaySeconds) saniye.")
                }
            }
            
            
        } else {
            // Delay 0 ise, bildirimi hemen göster:
            completion(updatedContent)
        }
    }*/
    
   /* private func handleActionBasedCompletion(with content: UNMutableNotificationContent,
                                               type: String,
                                               request: UNNotificationRequest,
                                               userInfo: [AnyHashable: Any],
                                               delayMinutes: Int,
                                               completion: @escaping (UNNotificationContent) -> Void) {
        // Öncelikle, DB insert işlemi duplicate kontrolü ile yapılıyor.
        DispatchQueue.global(qos: .background).async {
            self.saveToCoreData(type: type, request: request, userInfo: userInfo)
        }
        
        // Delay değeri 0'dan büyükse, bildirimin gösterimini geciktiriyoruz.
        if delayMinutes > 0 {
            let delaySeconds = TimeInterval(delayMinutes * 60)
            print("Action-based notification will be delayed by \(delayMinutes) minute(s) (\(delaySeconds) seconds).")
            DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
                completion(content)
            }
        } else {
            // Delay 0 ise hemen göster
            completion(content)
        }
    }*/
    
        
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
                    // Handle push notification
                    pushNotification(userInfo, content, request, completion)
                    break
                case .actionBased:
                    print("FCM customNotification action based")
                    actionBasedNotification(userInfo, content, request, completion)
                    break
                case .geofence:
                    print("FCM customNotification geofence")
                    geofenceNotification(userInfo, content, request, completion)
                    break
                case .inApp:
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

   
   
    public func saveToCoreData(
        type: String,
        request: UNNotificationRequest,
        userInfo: [AnyHashable : Any]
    ) {
        let identifier = request.identifier
        
        if !CoreDataManager.shared.notificationExists(withIdentifier: identifier){
            
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

