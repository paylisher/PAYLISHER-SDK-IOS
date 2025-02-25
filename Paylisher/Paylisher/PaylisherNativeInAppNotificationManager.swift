//
//  PaylisherNotificationManager.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 14.02.2025.
//

import Foundation
import UIKit


@available(iOSApplicationExtension, unavailable)
public class PaylisherNativeInAppNotificationManager {
    
    public static let shared = PaylisherNativeInAppNotificationManager()

    private init() {
        
    }

    public func nativeInAppNotification(userInfo: [AnyHashable: Any]) {
        
        guard let nativeString = userInfo["native"] as? String,
              !nativeString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = nativeString.data(using: .utf8),
              let nativeDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              !nativeDict.isEmpty else {
            return
        }
        
        let defaultLang = userInfo["defaultLang"] as? String ?? "en"
        
        let titleDict = nativeDict["title"] as? [String: String] ?? [:]
        
        let bodyDict  = nativeDict["body"]  as? [String: String] ?? [:]
        
        let imageUrl  = nativeDict["imageUrl"] as? String
        
        let actionUrl = nativeDict["actionUrl"] as? String
        
        let type = userInfo["type"] as? String
        
        let actionText = nativeDict["actionText"] as? String ?? ""
        
        let localizedTitle = titleDict[defaultLang] ?? titleDict.values.first ?? "No Title"
        
        let localizedBody  = bodyDict[defaultLang]  ?? bodyDict.values.first ?? "No Body"
        
        let identifier = UUID().uuidString
        
       
        let inAppVC = PaylisherInAppModalViewController(
            title: localizedTitle,
            body: localizedBody,
            imageUrl: imageUrl,
            actionUrl: actionUrl,
            actionText: actionText,
            identifier: identifier
        )
 
        if CoreDataManager.shared.notificationExists(withIdentifier: identifier) {
            print("Bildirim zaten kaydedilmiş, tekrar eklenmiyor.")
        } else {
            
            CoreDataManager.shared.insertNotification(
                type: type ?? "UNKNOWN",
                receivedDate: Date(),
                expirationDate: Date().addingTimeInterval(120),
                payload: userInfo.description,
                status: "UNREAD",
                identifier: identifier
            )
            print("Bildirim Core Data'ya kaydedildi!")
        }
        
        DispatchQueue.main.async {
            if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
                rootVC.present(inAppVC, animated: true, completion: nil)
            }
        }
        
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
    
}


