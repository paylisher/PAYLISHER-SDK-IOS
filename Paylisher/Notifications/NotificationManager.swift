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
        content.categoryIdentifier = PaylisherNotificationEventTracker.trackedCategoryIdentifier
        PaylisherNotificationEventTracker.registerTrackedCategory()
        
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
                if PaylisherNotificationDedupe.tryClaimReceived(userInfo: userInfo) {
                    PaylisherNotificationEventTracker.capture(
                        "notificationReceived",
                        userInfo: userInfo
                    )
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
        content.categoryIdentifier = PaylisherNotificationEventTracker.trackedCategoryIdentifier
        PaylisherNotificationEventTracker.registerTrackedCategory()
        
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
                if PaylisherNotificationDedupe.tryClaimReceived(userInfo: userInfo) {
                    PaylisherNotificationEventTracker.capture(
                        "notificationReceived",
                        userInfo: userInfo
                    )
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
        content.categoryIdentifier = PaylisherNotificationEventTracker.trackedCategoryIdentifier
        PaylisherNotificationEventTracker.registerTrackedCategory()
        
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
                if PaylisherNotificationDedupe.tryClaimReceived(userInfo: userInfo) {
                    PaylisherNotificationEventTracker.capture(
                        "notificationReceived",
                        userInfo: userInfo
                    )
                }
                
               completion(updatedContent)
            }
        } else {
            print("No image found; continuing without an image.")
            
            DispatchQueue.global(qos: .background).async {
                self.saveToCoreData(type: type, request: request, userInfo: userInfo)
            }
            if PaylisherNotificationDedupe.tryClaimReceived(userInfo: userInfo) {
                PaylisherNotificationEventTracker.capture(
                    "notificationReceived",
                    userInfo: userInfo,
                    properties: ["type": type]
                )
            }
            
            completion(content)
        }
    }
    
  /*  private func silentNotification(_ userInfo: [AnyHashable : Any], _ content: UNMutableNotificationContent, _ request: UNNotificationRequest, _ completion: @escaping (UNNotificationContent) -> Void) {
        
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
                    // Reception log — matches Android `FCM | InApp` shape.
                    // Includes the full FCM userInfo (parity with
                    // `FcmMessageHandler.handleInAppPayload` →
                    // "Notification InApp Data: $dataPayloadJson") so the
                    // exact payload is reproducible from the logs alone.
                    let pushId = (userInfo["pushId"] as? String) ?? "?"
                    let layoutType = (userInfo["layoutType"] as? String) ?? "?"
                    let gcmMessageId = (userInfo["gcm.message_id"] as? String) ?? "?"
                    print("FCM | InApp | Notification InApp Data: \(userInfo)")
                    print("FCM | InApp | received | pushId=\(pushId) | layoutType=\(layoutType) | gcmMessageId=\(gcmMessageId)")

                    if PaylisherNotificationDedupe.tryClaimReceived(userInfo: userInfo) {
                        print("FCM | InApp | dedupe claimed → capturing notificationReceived | pushId=\(pushId)")
                        PaylisherNotificationEventTracker.capture(
                            "notificationReceived",
                            userInfo: userInfo,
                            properties: ["type": typeString]
                        )
                    } else {
                        print("FCM | InApp | duplicate skipped | pushId=\(pushId) | gcmMessageId=\(gcmMessageId)")
                    }

                    print("FCM | InApp | routing → native + custom | pushId=\(pushId) | layoutType=\(layoutType)")
                    PaylisherNativeInAppNotificationManager.shared.nativeInAppNotification(userInfo: userInfo, windowScene: windowScene)
                    PaylisherCustomInAppNotificationManager.shared.parseInAppPayload(from: userInfo, windowScene: windowScene)
                    PaylisherCustomInAppNotificationManager.shared.customInAppFunction(userInfo: userInfo, windowScene: windowScene)

                    break
                case .silentHeartbeat:
                    // Silent heartbeat: no notification shown, only backend ack
                    // Processing is handled by PaylisherHeartbeatManager via PaylisherSDK.handleSilentPush()
                    print("FCM customNotification silentHeartbeat - handled silently")
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

    /// Capture a `notificationOpen` event when the app is cold-launched by tapping a
    /// notification that iOS displayed itself (e.g. a remote push without
    /// `mutable-content: 1`, where the Notification Service Extension never ran). Call this
    /// from `application(_:didFinishLaunchingWithOptions:)` after the SDK is set up. The
    /// `didReceive response` delegate will *also* fire shortly after; this helper dedupes via
    /// `gcm.message_id` / `google.message_id` so the event is captured exactly once.
    @discardableResult
    public func handleLaunchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        guard let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] else {
            return false
        }

        let hasPaylisherSource = (userInfo["source"] as? String) == "Paylisher"
        let pushId = PaylisherNotificationEventTracker.pushId(from: userInfo)
        guard hasPaylisherSource || pushId != nil else {
            return false
        }

        guard PaylisherNotificationDedupe.tryClaimOpen(userInfo: userInfo) else {
            return false
        }

        PaylisherNotificationEventTracker.capture(
            "notificationOpen",
            userInfo: userInfo,
            properties: ["via": "launchOptions"]
        )
        return true
    }

    /// Capture the `notificationReceived` event for a notification iOS is about to present
    /// while the app is in the foreground. The host app should call this from
    /// `userNotificationCenter(_:willPresent:withCompletionHandler:)` *before* invoking the
    /// completion handler. Returns `true` if the notification was tracked.
    @discardableResult
    public func handleForegroundPresentation(_ notification: UNNotification) -> Bool {
        let userInfo = notification.request.content.userInfo

        let hasPaylisherSource = (userInfo["source"] as? String) == "Paylisher"
        let pushId = PaylisherNotificationEventTracker.pushId(from: userInfo)
        guard hasPaylisherSource || pushId != nil else {
            return false
        }

        if PaylisherNotificationDedupe.tryClaimReceived(userInfo: userInfo) {
            PaylisherNotificationEventTracker.capture(
                "notificationReceived",
                userInfo: userInfo
            )
        }
        return true
    }

    @discardableResult
    public func handleNotificationResponse(_ response: UNNotificationResponse) -> Bool {
        let userInfo = response.notification.request.content.userInfo

        // Accept the notification if it carries a Paylisher pushId, even when the source
        // marker is missing (some foreground delivery paths drop top-level data keys).
        let hasPaylisherSource = (userInfo["source"] as? String) == "Paylisher"
        let hasPushId = PaylisherNotificationEventTracker.pushId(from: userInfo) != nil
        guard hasPaylisherSource || hasPushId else {
            return false
        }

        if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            PaylisherNotificationEventTracker.capture(
                "notificationDismiss",
                userInfo: userInfo,
                properties: ["via": "dismissAction"]
            )
            return true
        }

        // Skip if we already captured this open from launchOptions on cold start.
        guard PaylisherNotificationDedupe.tryClaimOpen(userInfo: userInfo) else {
            return true
        }

        PaylisherNotificationEventTracker.capture(
            "notificationOpen",
            userInfo: userInfo
        )

        if let actionURLString = userInfo["action"] as? String,
           !actionURLString.isEmpty,
           let actionURL = URL(string: actionURLString) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIApplication.shared.open(actionURL, options: [:], completionHandler: { success in
                    print("FCM -> URL açma sonucu: \(success), url: \(actionURLString)")
                })
            }
        } else {
            print("Action URL bulunamadı veya boş! action değeri: \(userInfo["action"] ?? "nil")")
        }

        return true
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

/// Cross-call dedupe for notificationOpen so that, on cold start from a notification tap,
/// `handleLaunchOptions` and `userNotificationCenter(_:didReceive:withCompletionHandler:)`
/// don't both end up emitting the event for the same push. Keyed by the FCM message id when
/// available, falling back to pushId.
///
/// Public so host apps that capture `notificationOpen` themselves (instead of going through
/// `NotificationManager.handleNotificationResponse`) can also participate in the dedupe by
/// gating their capture on `tryClaimOpen(userInfo:)`.
public enum PaylisherNotificationDedupe {
    private static let openClaimedKeyPrefix = "paylisher.notification.open.claimed."
    // Bound the marker history so UserDefaults doesn't grow forever.
    private static let openStoredKeysList = "paylisher.notification.open.claimed.keys"
    private static let receivedClaimedKeyPrefix = "paylisher.notification.received.claimed."
    private static let receivedStoredKeysList = "paylisher.notification.received.claimed.keys"
    private static let maxStoredKeys = 200

    static func messageKey(from userInfo: [AnyHashable: Any]) -> String? {
        let candidates = ["gcm.message_id", "google.message_id", "pushId"]
        for key in candidates {
            if let value = userInfo[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func tryClaim(
        userInfo: [AnyHashable: Any],
        keyPrefix: String,
        listKey: String
    ) -> Bool {
        guard let key = messageKey(from: userInfo) else {
            // No identifier to dedupe on — let the caller fire optimistically.
            return true
        }
        let defaults = UserDefaults.standard
        let storageKey = "\(keyPrefix)\(key)"
        if defaults.bool(forKey: storageKey) {
            return false
        }

        var stored = defaults.stringArray(forKey: listKey) ?? []
        stored.append(storageKey)
        if stored.count > maxStoredKeys {
            let evict = stored.prefix(stored.count - maxStoredKeys)
            for k in evict {
                defaults.removeObject(forKey: k)
            }
            stored = Array(stored.suffix(maxStoredKeys))
        }
        defaults.set(stored, forKey: listKey)
        defaults.set(true, forKey: storageKey)
        return true
    }

    /// Atomically marks the open event for `userInfo` as captured. Returns `true` if the
    /// caller should fire the event (first claim) and `false` if another path already did.
    public static func tryClaimOpen(userInfo: [AnyHashable: Any]) -> Bool {
        return tryClaim(
            userInfo: userInfo,
            keyPrefix: openClaimedKeyPrefix,
            listKey: openStoredKeysList
        )
    }

    /// Atomically marks the received event for `userInfo` as captured. Same semantics as
    /// `tryClaimOpen`, but for `notificationReceived` so dual-delegate paths
    /// (willPresent + didReceiveRemoteNotification, NSE + AppDelegate, etc.) don't
    /// double-fire it for the same FCM message.
    public static func tryClaimReceived(userInfo: [AnyHashable: Any]) -> Bool {
        return tryClaim(
            userInfo: userInfo,
            keyPrefix: receivedClaimedKeyPrefix,
            listKey: receivedStoredKeysList
        )
    }
}

enum PaylisherNotificationEventTracker {
    static let trackedCategoryIdentifier = "com.paylisher.notification.tracked"

    /// Standard Paylisher push fields that the backend may set on the data payload. Extracted
    /// automatically into every notification event so host apps don't have to hand-roll a
    /// property mapping.
    private static let standardUserInfoKeys = [
        "type",
        "pushId",
        "pushCanonicalId",
        "action",
        "actionType",
        "abExperimentId",
        "abVariantId",
        "abVariantLabel",
        "abPhase",
        "abObjective",
        "title"
    ]

    static func normalizePushId(_ pushId: String?) -> String? {
        let trimmed = pushId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    static func pushId(from userInfo: [AnyHashable: Any]) -> String? {
        normalizePushId(userInfo["pushId"] as? String)
    }

    /// Pull the standard Paylisher push fields out of the FCM `userInfo` and produce the base
    /// property map used by every notification event. Empty / whitespace-only string values
    /// are dropped so they don't pollute the event.
    static func extractStandardProperties(from userInfo: [AnyHashable: Any]) -> [String: Any] {
        var props: [String: Any] = ["deliveryChannel": "push"]
        for key in standardUserInfoKeys {
            guard let raw = userInfo[key] else { continue }
            if let s = raw as? String {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    props[key] = trimmed
                }
            } else {
                props[key] = raw
            }
        }
        return props
    }

    static func buildProperties(pushId: String?, properties: [String: Any?] = [:]) -> [String: Any] {
        var result: [String: Any] = [:]

        if let pushId {
            result["pushId"] = pushId
        }

        for (key, value) in properties {
            if let value {
                result[key] = value
            }
        }

        return result
    }

    static func capture(_ event: String, pushId: String?, properties: [String: Any?] = [:]) {
        PaylisherSDK.shared.capture(
            event,
            properties: buildProperties(pushId: pushId, properties: properties)
        )
    }

    static func capture(_ event: String, userInfo: [AnyHashable: Any], properties: [String: Any?] = [:]) {
        var merged = extractStandardProperties(from: userInfo)
        for (key, value) in properties {
            if let value {
                merged[key] = value
            }
        }
        PaylisherSDK.shared.capture(event, properties: merged)
    }

    static func registerTrackedCategory() {
        let center = UNUserNotificationCenter.current()
        let category = UNNotificationCategory(
            identifier: trackedCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.getNotificationCategories { categories in
            var updatedCategories = categories.filter { $0.identifier != trackedCategoryIdentifier }
            updatedCategories.insert(category)
            center.setNotificationCategories(updatedCategories)
        }
    }
}
