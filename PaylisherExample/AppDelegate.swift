//
//  AppDelegate.swift
//  PaylisherExample
//
//  Created by Ben White on 10.01.23.
//

import Foundation
import Paylisher
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import Combine
import CoreData

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate  {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launcOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool{

        let PAYLISHER_API_KEY = "phc_vFmOmzIfHMJtUvcTI8qCQu7VDPdKtO8Mz3kic7AIIvj" // "<phc_test>"
        let PAYLISHER_HOST = "https://datastudio.paylisher.com"  //"<https://test.paylisher.com>"

        let config = PaylisherConfig(apiKey: PAYLISHER_API_KEY, host: PAYLISHER_HOST)
        
    
        // the ScreenViews for SwiftUI does not work, the names are not useful
        config.captureScreenViews = true
        config.captureApplicationLifecycleEvents = true
//        config.flushAt = 1
//        config.flushIntervalSeconds = 30
        config.debug = true
        config.sendFeatureFlagEvent = true
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = true
        
        FirebaseApp.configure()
               
               if #available(iOS 10.0, *){
                   
                   UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                       guard granted else {
                           return
                       }
                       print("Granted in APNS registry")
                   }
                   UNUserNotificationCenter.current().delegate = self
                   Messaging.messaging().delegate = self
                   
               }
               application.registerForRemoteNotifications()
        
        let type = Paylisher.NotificationTypee.push
        
        
        
        
        PaylisherSDK.shared.setup(config)
        
        
//        PaylisherSDK.shared.debug()
        PaylisherSDK.shared.capture("App started!")
//        PaylisherSDK.shared.reset()
        
        PaylisherSDK.shared.capture("Logged in",
                                    userProperties: ["Email": "kayarasimburak@gmail.com", "Name": "Rasim Burak", "Surname:": "Kaya", "Gender": "Male"],
                                    userPropertiesSetOnce: ["date_of_first_log_in": "2025-23-01"])

        PaylisherSDK.shared.screen("App screen", properties: ["fromIcon": "bottom"])

        let defaultCenter = NotificationCenter.default

        #if os(iOS) || os(tvOS)
            defaultCenter.addObserver(self,
                                      selector: #selector(receiveFeatureFlags),
                                      name: PaylisherSDK.didReceiveFeatureFlags,
                                      object: nil)
        #endif

        return true
    }

    @objc func receiveFeatureFlags() {
        print("user receiveFeatureFlags callback")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
           
           Messaging.messaging().apnsToken = deviceToken
           
       }
       
      func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
           
          print("test -> willPresents")
          
         /* let userInfo = notification.request.content.userInfo
          
          let identifier = notification.request.identifier
          
          print("User Info: \(userInfo)")
          
          let title = userInfo["title"] as? String ?? "title"
          
          let message = userInfo["message"] as? String ?? "message"
          
          let type = userInfo["type"] as? String ?? "Unknown"
          
          print("Title: \(title)")
          
          print("Message: \(message)")
          
          CoreDataManager.shared.insertNotification(type: type, receivedDate: Date(), expirationDate: Date().addingTimeInterval(120), payload: userInfo.description, status: "UNREAD", identifier: identifier)
          
          let allNotifications = CoreDataManager.shared.fetchAllNotifications()
          print("allNotifications count: \(allNotifications.count)")
                for notification in allNotifications {
                    print("""
                    ID: \(notification.id)
                    Tür: \(notification.type)
                    Alınma Tarihi: \(notification.receivedDate ?? Date())
                    Durum: \(notification.status)
                    İçerik: \(notification.payload ?? "Boş")
                    Identifier: \(notification.notificationIdentifier)
                    """)
                }*/

          completionHandler([.sound, .list, .banner, .badge ])
       }
       
       func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
           
           let userInfo = response.notification.request.content.userInfo
           
           let identifier = response.notification.request.identifier
           
           CoreDataManager.shared.updateNotificationStatus(byIdentifier: identifier, newStatus: "READ")
         
           if let actionURLString = userInfo["action"] as? String,
              let actionURL = URL(string: actionURLString) {
               print("Bildirime tıklandı, açılan URL: \(actionURL)")
               UIApplication.shared.open(actionURL, options: [:], completionHandler: nil)
           } else {
               print("Action URL bulunamadı!")
           }
           
           completionHandler()
  
       }
       
       @objc func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
           
           messaging.token{ token, _ in
               guard let token = token else{
                   return
               }
               print("token: \(token)")
               
               PaylisherSDK.shared.identify( "Test-iOS_",
                                             userProperties :[
                                                "name": "Paylisher iOS",
                                                "email": "ios_soi@test.com",
                                                "token": token
                                             ],
               userPropertiesSetOnce : ["birthday": "2024-03-01"])
           }
       }
}
