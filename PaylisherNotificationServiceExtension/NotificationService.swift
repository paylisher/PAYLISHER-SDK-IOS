//
//  NotificationService.swift
//  PaylisherNotificationServiceExtension
//
//  Created by Rasim Burak Kaya on 11.02.2025.
//

import MobileCoreServices
import UserNotifications
import Paylisher 
import UIKit
import CoreData

class NotificationService: UNNotificationServiceExtension {
    

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
 
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) ->
            Void
    ) {
        
        // 1. Make the content mutable
        guard let bestAttemptContent = request.content.mutableCopy()
                as? UNMutableNotificationContent else {
            // If we can't make it mutable, just pass the original content
            contentHandler(request.content)
            return
        }
        
        // 2. Store these if you need them at the instance level
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        
        // 3. Call your custom method, passing in all necessary data
     /*   NotificationManager.showNotification(
            with: bestAttemptContent,
            for: request
        ) { updatedContent in
            // 4. Once your custom method finishes (even if asynchronously),
            //    call the contentHandler with the final content.
            contentHandler(updatedContent)
        } */
        
        NotificationManager.shared.showNotification(with: bestAttemptContent,
                                                    for: request) { updatedContent in
            // 4. Once your custom method finishes (even if asynchronously),
            //    call the contentHandler with the final content.
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

