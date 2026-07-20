//
//  PaylisherNotificationManager.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 14.02.2025.
//

import Foundation
import UIKit


//@available(iOSApplicationExtension, unavailable)
public class PaylisherNativeInAppNotificationManager {
 
   public init() {
    }
    
    public static let shared = PaylisherNativeInAppNotificationManager()

    public func nativeInAppNotification(userInfo: [AnyHashable: Any], windowScene: UIWindowScene?) {

        // Native path is opt-in: only fires when the FCM payload carries a
        // non-empty `native` field. Log the skip cases explicitly so it's
        // unambiguous in the trail when the layoutType is non-native (e.g.
        // banner/modal/fullscreen — those are handled by Custom manager).
        guard let nativeString = userInfo["native"] as? String, !nativeString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("FCM | InApp | Native skipped — payload has no `native` field (layoutType=\(userInfo["layoutType"] ?? "?") )")
            return
        }
        guard let data = nativeString.data(using: .utf8),
              let nativeDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              !nativeDict.isEmpty else {
            print("FCM | InApp | Native skipped — `native` JSON parse failed | raw=\(nativeString.prefix(200))…")
            return
        }
        
        // Optional on purpose: this comes from a server payload we do not control,
        // and `localize` already falls back (device language -> defaultLang -> first
        // available translation -> fallback). Force-casting it crashed the host app
        // whenever a campaign omitted the field.
        let defaultLang = userInfo["defaultLang"] as? String
        
        let titleDict = nativeDict["title"] as? [String: String] ?? [:]

        let bodyDict  = nativeDict["body"]  as? [String: String] ?? [:]

        // Per-field text alignment — authored on Studio
        // ("left" | "center" | "right"). Falls back to "center" on
        // missing / unknown values; same default the Studio preview uses.
        let titleAlign = (nativeDict["titleAlign"] as? String) ?? "center"
        let bodyAlign  = (nativeDict["bodyAlign"]  as? String) ?? "center"

        let actionUrl = nativeDict["actionUrl"] as? String ?? ""

        let type = userInfo["type"] as? String ?? "Native IN-APP"

        // actionText is authored per-language (a { lang: text } map), exactly
        // like title/body — localize it on-device so the action button matches
        // the device language. Legacy single-language string payloads still
        // render via the `as? String` fallback.
        let actionText: String
        if let actionTextDict = nativeDict["actionText"] as? [String: String] {
            actionText = actionTextDict.localize(defaultLang)
        } else {
            actionText = nativeDict["actionText"] as? String ?? ""
        }

        let localizedTitle = titleDict.localize(defaultLang)

        let localizedBody = bodyDict.localize(defaultLang)

        let gcmMessageID = userInfo["gcm.message_id"] as? String ?? ""
        let pushId = PaylisherNotificationEventTracker.pushId(from: userInfo)

        // Native parsed — mirrors Android InAppTaskWorker "InApp parsed"
        // log + "Showing NATIVE" routing log, but compact (single line).
        print("FCM | InApp | Native parsed | pushId=\(pushId ?? "?") | gcmMessageId=\(gcmMessageID) | titleLen=\(localizedTitle.count) | bodyLen=\(localizedBody.count) | titleAlign=\(titleAlign) | bodyAlign=\(bodyAlign) | hasAction=\(!actionText.isEmpty)")
        print("FCM | InApp | Showing NATIVE | pushId=\(pushId ?? "?")")

        let inAppVC = PaylisherInAppModalViewController(
            title: localizedTitle,
            body: localizedBody,
            titleAlign: titleAlign,
            bodyAlign: bodyAlign,
            actionUrl: actionUrl,
            actionText: actionText,
            gcmMessageID: gcmMessageID
        )
        
        
 
        if CoreDataManager.shared.notificationExists(withMessageID: gcmMessageID) {
            print("Bildirim zaten kaydedilmiş, tekrar eklenmiyor.")
        } else {
            
            CoreDataManager.shared.insertNotification(
                type: type,
                receivedDate: Date(),
                expirationDate: Date().addingTimeInterval(120),
                payload: userInfo.description,
                status: "UNREAD",
                gcmMessageID: gcmMessageID
            )
            print("Bildirim Core Data'ya kaydedildi!")
        }
        
       /* DispatchQueue.main.async {
            if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
                rootVC.present(inAppVC, animated: true, completion: nil)
            }
       }*/
//        #if IOS
        DispatchQueue.main.async {
//            if let windowScene = UIApplication.shared.connectedScenes
//                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            if windowScene != nil,
               let keyWindow = windowScene?.windows.first(where: { $0.isKeyWindow }),
               let rootVC = keyWindow.rootViewController {
                   // Kök VC zaten bir modal sunuyorsa present sessizce düşüyordu;
                   // en üstteki VC'den sun.
                   let presenter = PaylisherTopViewControllerResolver.topViewController(from: rootVC) ?? rootVC
                   presenter.present(inAppVC, animated: true) {
                       PaylisherNotificationEventTracker.capture(
                           "inappMessageRead",
                           pushId: pushId,
                           properties: ["type": "Native"]
                       )
                   }
            }
        }
//        #endif
      
        
        let notifications = CoreDataManager.shared.fetchAllNotifications()
        print("Core Data'daki Bildirimler (\(notifications.count) kayıt var):")

        for notification in notifications {
            print("""
            ID: \(notification.id)
            Tür: \(notification.type ?? type)
            Alınma Tarihi: \(notification.receivedDate ?? Date())
            Durum: \(notification.status ?? "UNREAD")
            İçerik: \(notification.payload ?? "Boş")
            MessageID: \(notification.gcmMessageID)
            
            """)
        }
    }
    
    

    
}

