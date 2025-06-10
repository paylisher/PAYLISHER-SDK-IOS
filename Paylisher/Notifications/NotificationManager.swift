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
import CoreLocation

 
public class NotificationManager: NSObject{
     
    public static let shared = NotificationManager()
   
    private let insideKeyPrefix = "geofence_inside_"
    
    //private let everEnteredKeyPrefix = "geofence_ever_entered_"
    
   
    
    private func pushNotification(_ userInfo: [AnyHashable : Any], _ content: UNMutableNotificationContent, _ request: UNNotificationRequest, _ completion: @escaping (UNNotificationContent) -> Void) {
        let pushNotification = PushPayload.shared.pushPayload(userInfo: userInfo)
        
        let defaultLang = pushNotification.defaultLang
        let localizedTitle = parseJSONString(pushNotification.title, language: defaultLang)
        let localizedMessage = parseJSONString(pushNotification.message, language: defaultLang)
        let action = pushNotification.action
        let silent = pushNotification.silent
        let imageUrl = pushNotification.imageUrl
        let type = pushNotification.type
        
        content.userInfo = userInfo
        
        if silent == "true" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound.default
        }
        
        content.title = localizedTitle
        content.body = localizedMessage
        
        DispatchQueue.global(qos: .background).async {
            self.saveToCoreData(type: type, userInfo: userInfo)
        }
        
        let deliver: (UNMutableNotificationContent) -> Void = { finalContent in
            // eğer artık gecikme istemiyorsanız anında göster:
            self.scheduleNotification(with: finalContent, at: Date())
            // ServiceExtension’da içeriği tamamla
            completion(finalContent)
        }

        if let url = URL(string: imageUrl) {
            addImageAttachment(from: url, to: content) { updatedContent in
                deliver(updatedContent)
            }
        } else {
            print("Görsel eklenemedi; attachment olmadan gönderiliyor.")
            deliver(content)
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
        let target = actionBasedNotification.condition.target
        
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
                 self.saveToCoreData(type: type, userInfo: userInfo)
             }
                
                // displayTime değerine göre zamanlamayı belirleyelim:
                if let displayTime = displayTime,
                   let displayTimeMillis = Double(displayTime) {
                    let displayDate = Date(timeIntervalSince1970: displayTimeMillis / 1000)
                    self.scheduleNotification(with: finalContent, at: displayDate)
                    print("geç gelmeli")
                } else {
                    // Eğer displayTime yoksa, bildirimi hemen gönderelim.
                    self.scheduleNotification(with: finalContent, at: Date())
                    print("şimdi gelmeli")
                }
                
                completion(finalContent)
            }
            
            if let imageUrl = URL(string: imageUrl) {
                addImageAttachment(from: imageUrl, to: content) { updatedContent in
                    processContent(updatedContent)
                }
            } else {
                print("No image found; continuing without an image.")
                processContent(content)
            }
        
       
    }
    
    public func setInside(_ inside: Bool, for geofenceId: String) {
        guard !geofenceId.isEmpty else {
                    print("Hata: geofenceId boş, setInside yapılamadı.")
                    return
                }
                UserDefaults.standard.set(inside, forKey: insideKeyPrefix + geofenceId)
                print("setInside: \(inside) for geofenceId: \(geofenceId)")
        }

        public func wasInside(_ geofenceId: String) -> Bool {
            guard !geofenceId.isEmpty else {
                        print("Hata: geofenceId boş, wasInside kontrol edilemedi.")
                        return false
                    }
                    let wasInside = UserDefaults.standard.bool(forKey: insideKeyPrefix + geofenceId)
                    print("wasInside: \(wasInside) for geofenceId: \(geofenceId)")
                    return wasInside
        }
    
    /*public func handleGeofenceEvent(geofenceId: String, trigger: String) {
           
            let notifications = CoreDataManager.shared.fetchAllNotifications()
            guard let notification = notifications.first(where: { notification in
                if let payload = notification.payload,
                   let data = payload.data(using: .utf8),
                   let userInfo = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable: Any],
                   let geofence = GeofencePayload.shared.parseGeofenceNotification(from: userInfo),
                   geofence.geofence?.geofenceId == geofenceId,
                   geofence.geofence?.trigger == trigger {
                    return true
                }
                return false
            }) else {
                print("Geofence bildirimi bulunamadı: \(geofenceId), Trigger: \(trigger)")
                return
            }
            
            if let payload = notification.payload,
               let data = payload.data(using: .utf8),
               let userInfo = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable: Any] {
                let content = UNMutableNotificationContent()
                let request = UNNotificationRequest(identifier: notification.gcmMessageID, content: content, trigger: nil)
                customNotification(windowScene: nil, userInfo: userInfo, content, request) { finalContent in
                    print("Geofence bildirimi tetiklendi: \(geofenceId), Trigger: \(trigger)")
                }
            }
        }*/
    
    private func geofenceNotification(_ userInfo: [AnyHashable: Any], _ content: UNMutableNotificationContent, _ request: UNNotificationRequest, _ completion: @escaping (UNNotificationContent) -> Void) {
        guard let geofenceNotification = GeofencePayload.shared.parseGeofenceNotification(from: userInfo) else {
            print("Payload parse edilemedi.")
            completion(content)
            return
        }
        
        let defaultLang = geofenceNotification.defaultLang
        let title = parseJSONString(geofenceNotification.title, language: defaultLang)
        let message = parseJSONString(geofenceNotification.message, language: defaultLang)
        let action = geofenceNotification.action
        let silent = geofenceNotification.silent
        let imageUrl = geofenceNotification.imageUrl ?? ""
        let type = geofenceNotification.type ?? ""
        let displayTime = geofenceNotification.condition?.displayTime
        let trigger = geofenceNotification.geofence?.trigger ?? ""
        let latitude = geofenceNotification.geofence?.latitude ?? 0
        let longitude = geofenceNotification.geofence?.longitude ?? 0
        let radiusStr = geofenceNotification.geofence?.radius ?? ""
        let filteredRadiusString = radiusStr.filter { char in
            return char.isNumber || char == "."
        }
        let radius = Double(filteredRadiusString) ?? 0
        let geofenceId = geofenceNotification.geofence?.geofenceId
        
        print("Trigger: \(trigger)")
        print("Latitude: \(latitude)")
        print("Longitude: \(longitude)")
        print("Radius: \(radius)")
        print("GeofenceId: \(geofenceId)")
        
        GeofenceManager.shared.addGeofence(
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            geofenceId: geofenceId ?? "",
            trigger: trigger
        )
        
        
        
        guard let location = GeofenceManager.shared.currentLocation else {
            print("Konum alınamadı, bildirim gönderilmedi (trigger: \(trigger), geofenceId: \(geofenceId)).")
            completion(content)
            return
        }
        
        let center = CLLocation(latitude: latitude, longitude: longitude)
        let distance = location.distance(from: center)
        let isCurrentlyInside = distance <= radius
        let wasPreviouslyInside = self.wasInside(geofenceId ?? "")
        
        print("Konum: \(location), Distance: \(distance)m, isCurrentlyInside: \(isCurrentlyInside), wasPreviouslyInside: \(wasPreviouslyInside)")
        
        var shouldFireNotification = false
        switch trigger {
        case "Entered":
            if isCurrentlyInside {
                shouldFireNotification = true
                self.setInside(true, for: geofenceId ?? "")
            }
        case "Exited":
            if !isCurrentlyInside && wasPreviouslyInside {
                shouldFireNotification = true
            }
        default:
            break
        }
        
        guard shouldFireNotification else {
            print("Kullanıcı şu an bu geofence için uygun değil (distance: \(distance)m, radius: \(radius)m, trigger: \(trigger)).")
            completion(content)
            return
        }
        
        content.userInfo = userInfo
        if silent == "true" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound.default
        }
        content.title = title
        content.body = message
        
        let processContent: (UNMutableNotificationContent) -> Void = { finalContent in
            DispatchQueue.global(qos: .background).async {
                self.saveToCoreData(type: type, userInfo: userInfo)
            }
            
            if let displayTime = displayTime,
               let displayTimeMillis = Double(displayTime) {
                let displayDate = Date(timeIntervalSince1970: displayTimeMillis / 1000)
                self.scheduleNotification(with: finalContent, at: displayDate)
            } else {
                self.scheduleNotification(with: finalContent, at: Date())
            }
            
            completion(finalContent)
        }
        
        if let imageUrl = URL(string: imageUrl) {
            self.addImageAttachment(from: imageUrl, to: content) { updatedContent in
                processContent(updatedContent)
            }
        } else {
            print("No image found; continuing without an image.")
            processContent(content)
        }
    }
    
    public func nativeInAppNotification(userInfo: [AnyHashable: Any], windowScene: UIWindowScene?) {
        
        
        guard let nativeString = userInfo["native"] as? String,
              let data = nativeString.data(using: .utf8),
              let nativeDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return
        }
        
       /* var displayTimeDate: Date?
        if let conditionString = userInfo["condition"] as? String,
           let condData       = conditionString.data(using: .utf8),
           let conditionDict  = try? JSONSerialization
            .jsonObject(with: condData) as? [String:Any],
           let dtString       = conditionDict["displayTime"] as? String,
           let dtMillis       = Double(dtString)
        {
            displayTimeDate = Date(timeIntervalSince1970: dtMillis/1000)
        }*/
        
        /* guard let conditionString = userInfo["condition"] as? String,
         !conditionString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
         let data = conditionString.data(using: .utf8),
         let conditionDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         !conditionDict.isEmpty else {
         return
         }*/
        
        let defaultLang = userInfo["defaultLang"] as! String
        
        let titleDict = nativeDict["title"] as? [String: String] ?? [:]
        
        let bodyDict  = nativeDict["body"]  as? [String: String] ?? [:]
        
        let imageUrl = nativeDict["imageUrl"] as? String ?? ""
        
        let actionUrl = nativeDict["actionUrl"] as? String ?? ""
        
        let type = userInfo["type"] as? String ?? "Native IN-APP"
        
        let actionText = nativeDict["actionText"] as? String ?? ""
        
        let localizedTitle = titleDict[defaultLang] ?? titleDict.values.first ?? "No Title"
        
        let localizedBody = bodyDict[defaultLang]  ?? bodyDict.values.first ?? "No Body"
        
        let gcmMessageID = userInfo["gcm.message_id"] as? String ?? ""

        let inAppVC = PaylisherInAppModalViewController(
            title: localizedTitle,
            body: localizedBody,
            imageUrl: imageUrl,
            actionUrl: actionUrl,
            actionText: actionText,
            gcmMessageID: gcmMessageID
        )
        
        DispatchQueue.global(qos: .background).async {
            self.saveToCoreData(type: type, userInfo: userInfo)
        }
        
         DispatchQueue.main.async {
         //            if let windowScene = UIApplication.shared.connectedScenes
         //                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
         if windowScene != nil,
         let keyWindow = windowScene?.windows.first(where: { $0.isKeyWindow }),
         let rootVC = keyWindow.rootViewController {
         rootVC.present(inAppVC, animated: true, completion: nil)
         }
         }
        
      /*  let showModal = {
            guard let ws = windowScene,
                  let window = ws.windows.first(where: { $0.isKeyWindow }),
                  let root  = window.rootViewController else {
                return
            }
            root.present(inAppVC, animated: true, completion: nil)
        }
        
        if let date = displayTimeDate {
            let delay = date.timeIntervalSinceNow
            if delay > 0 {
                // Geleceğe planla
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    showModal()
                }
            } else {
                // Süre dolmuş, hemen göster
                DispatchQueue.main.async {
                    showModal()
                }
            }
        } else {
            // condition/displayTime yoksa hemen göster
            DispatchQueue.main.async {
                showModal()
            }
        }*/
        
    }
    
    private func silentNotification(_ userInfo: [AnyHashable : Any], _ content: UNMutableNotificationContent, _ request: UNNotificationRequest, _ completion: @escaping (UNNotificationContent) -> Void) {
        
        let silentPayload = SilentPayload.shared.silentPayload(userInfo: userInfo)
        
        let defaultLang = silentPayload.defaultLang
        let title = parseJSONString(silentPayload.title, language: defaultLang)
        let message = parseJSONString(silentPayload.message, language: defaultLang)
        let action = silentPayload.action
        let silent = silentPayload.silent
        let type = silentPayload.type
        let imageUrl = silentPayload.imageUrl
        
        content.userInfo = userInfo
      
        content.sound = nil
        
        content.title = title
        content.body = message
        
        DispatchQueue.global(qos: .background).async {
            self.saveToCoreData(type: type, userInfo: userInfo)
        }
        
        let deliver: (UNMutableNotificationContent) -> Void = { finalContent in
            // eğer artık gecikme istemiyorsanız anında göster:
            self.scheduleNotification(with: finalContent, at: Date())
            // ServiceExtension’da içeriği tamamla
            completion(finalContent)
        }

        if let url = URL(string: imageUrl) {
            addImageAttachment(from: url, to: content) { updatedContent in
                deliver(updatedContent)
            }
        } else {
            print("Görsel eklenemedi; attachment olmadan gönderiliyor.")
            deliver(content)
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
                    
                        nativeInAppNotification(userInfo: userInfo, windowScene: windowScene)
                        PaylisherCustomInAppNotificationManager.shared.customInAppFunction(userInfo: userInfo, windowScene: windowScene)
 
                    break
               /* case .silent:
                    print("FCM customNotification silent")
                    silentNotification(userInfo, content, request, completion)*/
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
        
        let id = content.userInfo["gcm.message_id"] as? String
                    ?? UUID().uuidString

           let timeInterval = date.timeIntervalSinceNow
           if timeInterval <= 0 {
               
               let request = UNNotificationRequest(
                   identifier: id,
                   content:    content,
                   trigger:    nil
               )
               UNUserNotificationCenter.current().add(request) { error in
                   if let error = error {
                       print("Bildirim hemen gönderilirken hata: \(error)")
                   } else {
                       print("Bildirim hemen gönderildi. ID:", id)
                   }
               }
           } else {
               // 3) Geleceğe planla, aynı ID’yi kullan
               let components = Calendar.current.dateComponents(
                   [.year, .month, .day, .hour, .minute, .second],
                   from: date
               )
               let trigger = UNCalendarNotificationTrigger(
                   dateMatching: components,
                   repeats: false
               )
               let request = UNNotificationRequest(
                   identifier: id,        // 🎯 UUID değil, sabit ID
                   content:    content,
                   trigger:    trigger
               )
               UNUserNotificationCenter.current().add(request) { error in
                   if let error = error {
                       print("Local notification planlanırken hata: \(error)")
                   } else {
                       print("Local notification planlandı (ID: \(id)) @ \(date)")
                   }
               }
           }
        
    }

   
    public func saveToCoreData(
        type: String,
        userInfo: [AnyHashable : Any]
    ) {
        
        let jsonString: String
           do {
               let jsonData = try JSONSerialization.data(withJSONObject: userInfo, options: [])
               jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
           } catch {
               print("‼️ JSON oluşturma hatası:", error)
               // Fallback: en azından boş bir obje kaydet
               jsonString = "{}"
           }
        
        let gcmMessageID = userInfo["gcm.message_id"] as? String ?? ""
        
        var scheduledDate = Date() 
        if let conditionString = userInfo["condition"] as? String,
           let data = conditionString.data(using: .utf8),
           let conditionDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let displayTimeString = conditionDict["displayTime"] as? String,
           let displayTimeMillis = Double(displayTimeString) {
            scheduledDate = Date(timeIntervalSince1970: displayTimeMillis / 1000)
        }
        
        if CoreDataManager.shared.notificationExists(withMessageID: gcmMessageID) {
            print("Bildirim zaten kaydedilmiş, tekrar eklenmiyor.")
        } else {
            
            CoreDataManager.shared.insertNotification(
                type: type,
                receivedDate: scheduledDate,
                expirationDate: Date().addingTimeInterval(120),
                payload: jsonString,
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

extension NotificationManager: CLLocationManagerDelegate {
   
    
   
    /*public func showTargetNotifications(matching targetName: String) {
            let center   = UNUserNotificationCenter.current()
            let now      = Date()
            let entities = CoreDataManager.shared.fetchTargetNotifications()

            for entity in entities {
                // 1️⃣ payload → userInfo dict
                guard
                    let payloadStr = entity.payload,
                    let data       = payloadStr.data(using: .utf8),
                    let userInfo   = try? JSONSerialization
                                         .jsonObject(with: data, options: []) as? [AnyHashable:Any]
                else { continue }

                // 2️⃣ condition parsing
                guard
                    let condRaw  = userInfo["condition"] as? String,
                    let condData = condRaw.data(using: .utf8),
                    let condDict = try? JSONSerialization
                                        .jsonObject(with: condData, options: []) as? [String:Any],
                    let target   = condDict["target"] as? String,
                    target == targetName
                else { continue }

                // 3️⃣ displayTime kontrolü (varsa, gelecekteyse atla)
                if let dtStr = condDict["displayTime"] as? String,
                   let ms    = Double(dtStr) {
                    let displayDate = Date(timeIntervalSince1970: ms / 1000)
                    guard now >= displayDate else {
                        print("⏳ \(targetName) için henüz \(displayDate) bekleniyor")
                        continue
                    }
                }

                let id = entity.gcmMessageID

                // 4️⃣ varsa eskiden schedule edilmiş bir pending isteği iptal et
                center.removePendingNotificationRequests(withIdentifiers: [id])

                // 5️⃣ content & request hazırla
                let content = UNMutableNotificationContent()
                content.userInfo = userInfo

                let request = UNNotificationRequest(
                    identifier: id,
                    content:    content,
                    trigger:    nil
                )

                // 6️⃣ customNotification zincirini windowScene=nil ile çağır
                customNotification(
                    windowScene: nil,
                    with:        content,
                    for:         request
                ) { _ in
                    CoreDataManager.shared.updateNotificationStatus(
                        byMessageID: id,
                        newStatus:   "READ"
                    )
                }

                // eğer sadece ilk eşleşeni göstermek istersen:
                // break
            }
        }
    
    public func showTargetInAppNotifications(matching targetName: String) {
        let now      = Date()
        let entities = CoreDataManager.shared.fetchTargetNotifications()

        // Foreground’daki aktif windowScene’i bul
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        for entity in entities {
            // 1️⃣ CoreData’dan gelen JSON payload’ı parse et
            guard
                let payloadStr  = entity.payload,
                let payloadData = payloadStr.data(using: .utf8),
                let userInfo    = try? JSONSerialization
                                       .jsonObject(with: payloadData, options: [])
                                       as? [AnyHashable:Any]
            else { continue }

            // 2️⃣ Sadece “native” alanı olanları al
            guard
                let nativeStr  = userInfo["native"] as? String,
                let nativeData = nativeStr.data(using: .utf8),
                let nativeDict = try? JSONSerialization
                                       .jsonObject(with: nativeData, options: [])
                                       as? [String:Any]
            else {
                continue
            }

            // 3️⃣ condition → target kontrolü
            guard
                let condStr  = userInfo["condition"] as? String,
                let condData = condStr.data(using: .utf8),
                let condDict = try? JSONSerialization
                                       .jsonObject(with: condData, options: [])
                                       as? [String:Any],
                let target   = condDict["target"] as? String,
                target == targetName
            else {
                continue
            }

            // 4️⃣ displayTime varsa ve henüz zamanı gelmediyse atla
            if let dtString = condDict["displayTime"] as? String,
               let millis   = Double(dtString) {
                let displayDate = Date(timeIntervalSince1970: millis / 1000)
                guard now >= displayDate else {
                    print("⏳ \(targetName) için henüz \(displayDate) bekleniyor")
                    continue
                }
            }

            // 5️⃣ İşaretle: okunmuş
            CoreDataManager.shared.updateNotificationStatus(
                byMessageID: entity.gcmMessageID,
                newStatus:   "READ"
            )

            // 6️⃣ İn-app verilerini nativeDict’ten al
            let lang       = userInfo["defaultLang"] as? String ?? "tr"
            let titleDict  = nativeDict["title"] as? [String:String] ?? [:]
            let bodyDict   = nativeDict["body"]  as? [String:String] ?? [:]
            let titleText  = titleDict[lang] ?? titleDict.values.first ?? ""
            let bodyText   = bodyDict[lang] ?? bodyDict.values.first ?? ""
            let imageUrl   = nativeDict["imageUrl"]  as? String ?? ""
            let actionUrl  = nativeDict["actionUrl"] as? String ?? ""
            let actionText = nativeDict["actionText"] as? String ?? ""
            let gcmID      = userInfo["gcm.message_id"] as? String ?? UUID().uuidString

            // 7️⃣ Ana thread’de sunum
            DispatchQueue.main.async {
                guard
                    let scene  = windowScene,
                    let window = scene.windows.first(where: { $0.isKeyWindow }),
                    let rootVC = window.rootViewController
                else { return }

                // Eğer hâlihazırda bir modal açıksa kapat
                if let presented = rootVC.presentedViewController {
                    presented.dismiss(animated: false) {
                        self.presentNativeModal(
                            on: rootVC,
                            title: titleText,
                            body: bodyText,
                            imageUrl: imageUrl,
                            actionUrl: actionUrl,
                            actionText: actionText,
                            gcmMessageID: gcmID
                        )
                    }
                } else {
                    self.presentNativeModal(
                        on: rootVC,
                        title: titleText,
                        body: bodyText,
                        imageUrl: imageUrl,
                        actionUrl: actionUrl,
                        actionText: actionText,
                        gcmMessageID: gcmID
                    )
                }
            }

            // yalnızca ilk eşleşeni göster:
            break
        }
    }

    /// Modal’ı rootVC üzerinde gösteren helper
    private func presentNativeModal(
        on rootVC: UIViewController,
        title: String,
        body: String,
        imageUrl: String,
        actionUrl: String,
        actionText: String,
        gcmMessageID: String
    ) {
        let vc = PaylisherInAppModalViewController(
            title:        title,
            body:         body,
            imageUrl:     imageUrl,
            actionUrl:    actionUrl,
            actionText:   actionText,
            gcmMessageID: gcmMessageID
        )
        rootVC.present(vc, animated: true, completion: nil)
    }

 */
}
