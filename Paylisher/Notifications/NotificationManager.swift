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
        let displayTime = pushNotification.condition.displayTime
        
        content.userInfo = userInfo
        
        if silent == "true" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound.default
        }
        
        content.title = localizedTitle
        content.body = localizedMessage
        
        let processContent: (UNMutableNotificationContent) -> Void = { finalContent in
                // Öncelikle Core Data'ya kaydetme işlemini arka planda yapıyoruz.
            DispatchQueue.global(qos: .background).async {
                 self.saveToCoreData(type: type, request: request, userInfo: userInfo)
             }
                
                // displayTime değerine göre zamanlamayı belirleyelim:
                if let displayTime = displayTime,
                   let displayTimeMillis = Double(displayTime) {
                    let displayDate = Date(timeIntervalSince1970: displayTimeMillis / 1000)
                    // scheduleNotification(with:at:) metodumuz,
                    // timeInterval <= 0 ise trigger'ı nil yapıp bildirimi hemen gönderiyor.
                    self.scheduleNotification(with: finalContent, at: displayDate)
                } else {
                    // Eğer displayTime yoksa, bildirimi hemen gönderelim.
                    self.scheduleNotification(with: finalContent, at: Date())
                }
                
                completion(finalContent)
            }
            
            // Resim eklemek istiyorsak, imageUrl kontrolü:
            if let imageUrl = URL(string: imageUrl) {
                addImageAttachment(from: imageUrl, to: content) { updatedContent in
                    processContent(updatedContent)
                }
            } else {
                print("No image found; continuing without an image.")
                processContent(content)
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
        
        content.userInfo = userInfo
        
        if silent == "true" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound.default
        }
        
        content.title = title
        content.body = message
        
        let processContent: (UNMutableNotificationContent) -> Void = { finalContent in
                // Öncelikle Core Data'ya kaydetme işlemini arka planda yapıyoruz.
            DispatchQueue.global(qos: .background).async {
                 self.saveToCoreData(type: type, request: request, userInfo: userInfo)
             }
                
                // displayTime değerine göre zamanlamayı belirleyelim:
                if let displayTime = displayTime,
                   let displayTimeMillis = Double(displayTime) {
                    let displayDate = Date(timeIntervalSince1970: displayTimeMillis / 1000)
                    // scheduleNotification(with:at:) metodumuz,
                    // timeInterval <= 0 ise trigger'ı nil yapıp bildirimi hemen gönderiyor.
                    self.scheduleNotification(with: finalContent, at: displayDate)
                } else {
                    // Eğer displayTime yoksa, bildirimi hemen gönderelim.
                    self.scheduleNotification(with: finalContent, at: Date())
                }
                
                completion(finalContent)
            }
            
            // Resim eklemek istiyorsak, imageUrl kontrolü:
            if let imageUrl = URL(string: imageUrl) {
                addImageAttachment(from: imageUrl, to: content) { updatedContent in
                    processContent(updatedContent)
                }
            } else {
                print("No image found; continuing without an image.")
                processContent(content)
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
        
        content.userInfo = userInfo
        
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
    
    private func silentNotification(_ userInfo: [AnyHashable : Any], _ content: UNMutableNotificationContent, _ request: UNNotificationRequest, _ completion: @escaping (UNNotificationContent) -> Void) {
        
        let silentPayload = SilentPayload.shared.silentPayload(userInfo: userInfo)
        
        let title = silentPayload.title
        let message = silentPayload.message
        let action = silentPayload.action
        let silent = silentPayload.silent
        let type = silentPayload.type
        let imageUrl = silentPayload.imageUrl
        let displayTime = silentPayload.displayTime
        
        content.userInfo = userInfo
      
        if silent == "true" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound.default
        }
        
        content.title = title
        content.body = message
        
        let processContent: (UNMutableNotificationContent) -> Void = { finalContent in
                // Öncelikle Core Data'ya kaydetme işlemini arka planda yapıyoruz.
            DispatchQueue.global(qos: .background).async {
                self.saveToCoreData(type: type, request: request, userInfo: userInfo)
            }
            
            self.scheduleNotification(with: finalContent, at: Date())
                
                // displayTime değerine göre zamanlamayı belirleyelim:
             /*   if let displayTime = displayTime,
                   let displayTimeMillis = Double(displayTime) {
                    let displayDate = Date(timeIntervalSince1970: displayTimeMillis / 1000)
                    // scheduleNotification(with:at:) metodumuz,
                    // timeInterval <= 0 ise trigger'ı nil yapıp bildirimi hemen gönderiyor.
                    self.scheduleNotification(with: finalContent, at: displayDate)
                } else {
                    // Eğer displayTime yoksa, bildirimi hemen gönderelim.
                    self.scheduleNotification(with: finalContent, at: Date())
                }*/
                
                completion(finalContent)
            }
            
            // Resim eklemek istiyorsak, imageUrl kontrolü:
            if let imageUrl = URL(string: imageUrl) {
                addImageAttachment(from: imageUrl, to: content) { updatedContent in
                    processContent(updatedContent)
                }
            } else {
                print("No image found; continuing without an image.")
                processContent(content)
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
                case .silent:
                    print("FCM customNotification silent")
                    silentNotification(userInfo, content, request, completion)
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

    private func scheduleNotification(with content: UNMutableNotificationContent, at date: Date) {
        let timeInterval = date.timeIntervalSinceNow
        if timeInterval <= 0 {
            
            let userInfo = content.userInfo
            
            let request = UNNotificationRequest(identifier: userInfo["gcm.message_id"] as? String ?? "",
                                                  content: content,
                                                  trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Bildirim hemen gönderilirken hata: \(error)")
                } else {
                    print("Bildirim hemen gönderildi.")
                }
            }
        } else {
            // Belirlenen tarihe göre planla
            let triggerDate = Calendar.current.dateComponents(in: TimeZone.current, from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                  content: content,
                                                  trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Local notification planlanırken hata: \(error)")
                } else {
                    print("Local notification planlandı: \(date)")
                }
            }
        }
    }

   
    public func saveToCoreData(
        type: String,
        request: UNNotificationRequest,
        userInfo: [AnyHashable : Any]
    ) {
        let gcmMessageID = userInfo["gcm.message_id"] as? String ?? ""
        
        var scheduledDate = Date() 
        if let conditionString = userInfo["condition"] as? String,
           let data = conditionString.data(using: .utf8),
           let conditionDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let displayTimeString = conditionDict["displayTime"] as? String,
           let displayTimeMillis = Double(displayTimeString) {
            scheduledDate = Date(timeIntervalSince1970: displayTimeMillis / 1000)
        }
        
        //let userInfo = request.content.userInfo
        
      /*  if !CoreDataManager.shared.notificationExists(withIdentifier: identifier){
            
            CoreDataManager.shared.insertNotification(
                type: type,
                receivedDate: Date(),
                expirationDate: Date().addingTimeInterval(120),
                payload: userInfo.description,
                status: "UNREAD",
                identifier: identifier
            )
            
            print("Notification saved to Core Data!") */
        
        if CoreDataManager.shared.notificationExists(withMessageID: gcmMessageID) {
            print("Bildirim zaten kaydedilmiş, tekrar eklenmiyor.")
        } else {
            
            CoreDataManager.shared.insertNotification(
                type: type,
                receivedDate: scheduledDate,
                expirationDate: Date().addingTimeInterval(120),
                payload: userInfo.description,
                status: "UNREAD",
                gcmMessageID: gcmMessageID
            )
            print("Bildirim Core Data'ya kaydedildi!")
            
            let notifications = CoreDataManager.shared.fetchAllNotifications()
            print("Core Data Notifications (\(notifications.count) records):")
            
            for notification in notifications {
                print("""
            ID: \(notification.id)
            Type: \(notification.type ?? type)
            Received Date: \(notification.receivedDate ?? Date())
            Status: \(notification.status ?? "UNREAD")
            Payload: \(notification.payload ?? "Empty")
            MessageID: \(notification.gcmMessageID)
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

