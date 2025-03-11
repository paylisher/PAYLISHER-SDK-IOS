//
//  NotificationService.swift
//  PaylisherNotificationServiceExtension
//
//  Created by Rasim Burak Kaya on 11.02.2025.
//

import MobileCoreServices
import UserNotifications
//import Paylisher
import UIKit
import CoreData

//@available(iOSApplicationExtension, unavailable)
class NotificationService: UNNotificationServiceExtension {
    

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
 
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) ->
            Void
    ) {
        
        
        guard let bestAttemptContent = request.content.mutableCopy()
                as? UNMutableNotificationContent else {
            
            contentHandler(request.content)
            return
        }
        
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
       
        // TODO: windowScene needed but cant get it from here -> FIX IT
        let windowScene: UIWindowScene? = nil
       
       //   windowScene = UIApplication.shared.connectedScenes
         //   .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        
        
        
        let userInfo = bestAttemptContent.userInfo
        //print("FCM NotificationService -> didReceive \(userInfo["type"])")
        
        NotificationManager.shared.customNotification(windowScene: windowScene, with: bestAttemptContent,
                                                    for: request) { updatedContent in
            contentHandler(updatedContent)
        }
        
    

    }

    override func serviceExtensionTimeWillExpire() {

        if let contentHandler = contentHandler,
            let bestAttemptContent = bestAttemptContent
        {
            contentHandler(bestAttemptContent)
        }
    }
 }

