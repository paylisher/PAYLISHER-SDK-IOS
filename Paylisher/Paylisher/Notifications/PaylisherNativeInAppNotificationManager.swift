//
//  PaylisherNotificationManager.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 14.02.2025.
//

import Foundation
import UIKit

public protocol InAppNotificationDelegate: AnyObject {
    func presentInAppNotification(with data: InAppNotificationData)
}

public struct InAppNotificationData {
    public let title: String
    public let body: String
    public let imageUrl: String
    public let actionUrl: String
    public let actionText: String
    public let identifier: String
    public let type: String
    public let defaultLang: String
    public let userInfo: [AnyHashable: Any]

    public init(title: String,
                body: String,
                imageUrl: String,
                actionUrl: String,
                actionText: String,
                identifier: String,
                type: String,
                defaultLang: String,
                userInfo: [AnyHashable: Any]) {
        self.title = title
        self.body = body
        self.imageUrl = imageUrl
        self.actionUrl = actionUrl
        self.actionText = actionText
        self.identifier = identifier
        self.type = type
        self.defaultLang = defaultLang
        self.userInfo = userInfo
    }
}

@available(iOSApplicationExtension, unavailable)
public class PaylisherNativeInAppNotificationManager {
 
    var defaultLang: String = ""
    var title: String = ""
    var body: String = ""
    var imageUrl: String = ""
    var actionUrl: String = ""
    var type: String = ""
    var actionText: String = ""
    var identifier: String = ""
    var userInfo: [AnyHashable: Any] = [:]
 
   public init() {
    }
    
    public static let shared = PaylisherNativeInAppNotificationManager()
    
    public weak var delegate: InAppNotificationDelegate?

    public func nativeInAppNotification(userInfo: [AnyHashable: Any]) {
        
        
        guard let nativeString = userInfo["native"] as? String,
              !nativeString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = nativeString.data(using: .utf8),
              let nativeDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              !nativeDict.isEmpty else {
            return
        }
        
        self.userInfo = userInfo
        
        self.defaultLang = userInfo["defaultLang"] as! String
        
        let titleDict = nativeDict["title"] as? [String: String] ?? [:]
        
        let bodyDict  = nativeDict["body"]  as? [String: String] ?? [:]
        
        self.imageUrl = nativeDict["imageUrl"] as? String ?? ""
        
        self.actionUrl = nativeDict["actionUrl"] as? String ?? ""
        
        self.type = userInfo["type"] as? String ?? "Native IN-APP"
        
        self.actionText = nativeDict["actionText"] as? String ?? ""
        
        self.title = titleDict[defaultLang] ?? titleDict.values.first ?? "No Title"
        
        self.body = bodyDict[defaultLang]  ?? bodyDict.values.first ?? "No Body"
        
        self.identifier = UUID().uuidString
        
        let notificationData = InAppNotificationData(
                    title: self.title,
                    body: self.body,
                    imageUrl: self.imageUrl,
                    actionUrl: self.actionUrl,
                    actionText: self.actionText,
                    identifier: self.identifier,
                    type: self.type,
                    defaultLang: self.defaultLang,
                    userInfo: self.userInfo
                )
        
        DispatchQueue.main.async { [weak self] in
                    self?.delegate?.presentInAppNotification(with: notificationData)
                }
       
       /* let inAppVC = PaylisherInAppModalViewController(
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
        }*/
    }
    
    

    
}


