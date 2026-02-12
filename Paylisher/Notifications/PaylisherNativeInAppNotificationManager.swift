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

        let gcmMessageID = userInfo["gcm.message_id"] as? String ?? "no-id"
        print("📋 [NativeInApp] ================================")
        print("📋 [NativeInApp] nativeInAppNotification called")
        print("📋 [NativeInApp] gcm.message_id: \(gcmMessageID)")
        print("📋 [NativeInApp] windowScene: \(windowScene == nil ? "nil ⚠️" : "exists ✅")")
        print("📋 [NativeInApp] 'native' key exists: \(userInfo["native"] != nil)")
        if let nativeRaw = userInfo["native"] as? String {
            print("📋 [NativeInApp] native string length: \(nativeRaw.count)")
            print("📋 [NativeInApp] native string preview: \(String(nativeRaw.prefix(200)))")
        }

        guard let nativeString = userInfo["native"] as? String,
              !nativeString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = nativeString.data(using: .utf8),
              let nativeDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              !nativeDict.isEmpty else {
            print("📋 [NativeInApp] Guard failed - no valid 'native' payload, returning early")
            return
        }
        print("📋 [NativeInApp] Native payload parsed successfully. Keys: \(nativeDict.keys.sorted())")
        
        let defaultLang = userInfo["defaultLang"] as! String
        
        let titleDict = nativeDict["title"] as? [String: String] ?? [:]
        
        let bodyDict  = nativeDict["body"]  as? [String: String] ?? [:]
        
        let imageUrl = nativeDict["imageUrl"] as? String ?? ""
        
        let actionUrl = nativeDict["actionUrl"] as? String ?? ""
        
        let type = userInfo["type"] as? String ?? "Native IN-APP"
        
        let actionText = nativeDict["actionText"] as? String ?? ""
        
        let localizedTitle = titleDict[defaultLang] ?? titleDict.values.first ?? "No Title"
        
        let localizedBody = bodyDict[defaultLang]  ?? bodyDict.values.first ?? "No Body"
        

        let inAppVC = PaylisherInAppModalViewController(
            title: localizedTitle,
            body: localizedBody,
            imageUrl: imageUrl,
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
        
        DispatchQueue.main.async {
            print("📋 [NativeInApp] Attempting to present modal on main thread...")
            print("📋 [NativeInApp] windowScene: \(windowScene == nil ? "nil ⚠️" : "exists ✅")")

            if windowScene != nil,
               let keyWindow = windowScene?.windows.first(where: { $0.isKeyWindow }),
               let rootVC = keyWindow.rootViewController {
                print("✅ [NativeInApp] rootVC found: \(Swift.type(of: rootVC))")
                print("✅ [NativeInApp] Presenting in-app modal NOW")
                rootVC.present(inAppVC, animated: true, completion: {
                    print("✅ [NativeInApp] Modal presented successfully!")
                })
            } else {
                print("❌ [NativeInApp] FAILED to present modal!")
                if windowScene == nil {
                    print("❌ [NativeInApp]   Reason: windowScene is nil")
                } else if windowScene?.windows.first(where: { $0.isKeyWindow }) == nil {
                    print("❌ [NativeInApp]   Reason: No key window found")
                } else {
                    print("❌ [NativeInApp]   Reason: No rootViewController on key window")
                }
            }
        }
      
        
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


