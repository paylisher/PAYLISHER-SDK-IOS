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
import MobileCoreServices


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate  {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launcOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool{

      //  let PAYLISHER_API_KEY = "phc_JwUJI7MmnWguE6e211Ah0WMtedBQAmK25LupnwWQELE" // "<phc_test>"
      //  let PAYLISHER_HOST = "https://analytics.paylisher.com" //"<https://test.paylisher.com>"
        
        let PAYLISHER_API_KEY = "phc_vFmOmzIfHMJtUvcTI8qCQu7VDPdKtO8Mz3kic7AIIvj" // "<phc_test>"
        let PAYLISHER_HOST = "https://datastudio.paylisher.com" //"<https://test.paylisher.com>"

        let config = PaylisherConfig(apiKey: PAYLISHER_API_KEY, host: PAYLISHER_HOST)
        
        config.captureScreenViews = true
        config.captureApplicationLifecycleEvents = true
        config.flushAt = 1
        config.debug = true
        config.sendFeatureFlagEvent = true
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true
        config.sessionReplayConfig.maskAllTextInputs = false
        config.sessionReplayConfig.maskAllImages = false
       
        PaylisherSDK.shared.setup(config)
        
        //ViewLayoutTracker.swizzleLayoutSubviews()
  
        let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        
        
        

        
        FirebaseApp.configure()
               
               if #available(iOS 10.0, *){
                   
                   UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                       guard granted else {
                           return
                       }
                       print("Granted in APNS registry")
                   }
                  
               }

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
        
        CoreDataManager.shared.configure(appGroupIdentifier: "group.com.paylisher.Paylisher")
        
        //CoreDataManager.shared.deleteAllNotifications()
        //print("Tüm eski bildirimler silindi.")
    
//        PaylisherSDK.shared.debug()
        PaylisherSDK.shared.capture("App started!")
//        PaylisherSDK.shared.reset()
        
        PaylisherSDK.shared.capture("Logged in",
                                    userProperties: ["Email": "kayarasimburak@gmail.com", "Name": "Rasim Burak", "Surname:": "Kaya", "Gender": "Male"],
                                    userPropertiesSetOnce: ["date_of_first_log_in": "2025-23-01"])

        PaylisherSDK.shared.screen("App screen", properties: ["fromIcon": "bottom"])

        //PaylisherSDK.shared.getDistinctId()
        
        //PaylisherSDK.shared.identify("user_id_from_your_database")
        
        //print("Distinc id: \(PaylisherSDK.shared.getDistinctId())" )
        
      //  config.storageManager?.getDistinctId()
        
        LocationManager.shared.requestLocationPermission()
        
        GeofenceManager.shared.startGeofencing()

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
           
        
        print("FCM application -> didRegisterForRemoteNotificationsWithDeviceToken")
        Messaging.messaging().apnsToken = deviceToken
           
    }

      //var processedNotifications = Set<String>()
      func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
          
         let userInfo = notification.request.content.userInfo
         
       //   let notificationID = notification.request.identifier
          
          //let request = notification.request
          
        /*if processedNotifications.contains(notificationID) {
              print("Tekrarlanan bildirim algılandı, işlenmiyor.")
              return
          }
          processedNotifications.insert(notificationID)
          print("Bildirim ID’si: \(notificationID) - İşleniyor.")*/
    
      let mutableContent = UNMutableNotificationContent()
      mutableContent.title = notification.request.content.title
      mutableContent.subtitle = notification.request.content.subtitle
      mutableContent.body = notification.request.content.body
      mutableContent.sound = notification.request.content.sound
      mutableContent.badge = notification.request.content.badge
      mutableContent.userInfo = notification.request.content.userInfo
      mutableContent.categoryIdentifier = notification.request.content.categoryIdentifier
      
      // If you're using iOS 15+, you can copy additional properties
      if #available(iOS 15.0, *) {
          mutableContent.interruptionLevel = notification.request.content.interruptionLevel
          mutableContent.relevanceScore = notification.request.content.relevanceScore
      }
      
      let windowScene = UIApplication.shared.connectedScenes
          .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
      
          //let windowScene: UIWindowScene? = nil
       
          print("FCM -> willPresents")
      //    print(userInfo)
          
         
           //Normalde bu eventin bu fonksiyon altında yazılmaması gerekiyor çünkü bu fonksiyon uygulama ön plandayken bildirim geldiğinde aktif oluyor yani uygulama arka plandayken bildirim geldiğinde event gönderilmiyor. Aklında bulunsun, sonra düzelt.
           NotificationManager.shared.customNotification(
                  windowScene: windowScene,
                    userInfo: userInfo,
                    mutableContent,
                  notification.request,
                    { content in
                 
                            //   completionHandler([.banner, .sound])
                   }
       
                )
         /* let type = userInfo["type"] as? String
          
          if type != "IN-APP"{
              completionHandler([.sound, .list, .banner, .badge ])
          }else{
              
          }*/
              
          completionHandler([.sound, .list, .banner, .badge ])
              
       }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

              /*  let type = userInfo["type"] as? String ?? ""
                
                switch type {
                case "IN-APP":
                    print("Sessiz IN-APP alındı: \(userInfo)")
                    completionHandler(.newData)
                    
                    let content = UNMutableNotificationContent()
        
                    content.userInfo = userInfo

                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString,
                        content: content,
                        trigger: nil // sessiz push'ta trigger yok
                    )

                    NotificationManager.shared.saveToCoreData(type: type, request: request, userInfo: userInfo)
               
                default:
                    print("defffaaauuullttt")
                }*/
       
        
        PaylisherSDK.shared.capture("notificationReceived", properties: ["type": userInfo["type"],"pushId": userInfo["pushId"]])
        
       /* print("User Info: \(userInfo)")
       
        let state = UIApplication.shared.applicationState
        
        let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        
       let content = UNMutableNotificationContent()
        
       let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

        
        let request = UNNotificationRequest(
            identifier: userInfo["gcm.message_id"] as? String ?? "",
            content: content,
            trigger: trigger
         )
        
    
        let type = userInfo["type"] as? String ?? ""

        if let conditionString = userInfo["condition"] as? String,
           let data = conditionString.data(using: .utf8),
           let conditionDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let target = conditionDict["target"] as? String,
           !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
           
            NotificationManager.shared.saveToCoreData(type: type, userInfo: userInfo)
        } else {
        
            NotificationManager.shared.customNotification(
                windowScene: windowScene,
                userInfo: userInfo,
                content,
                request
            ) { modifiedContent in
               
            }
        }*/

        
       

    }

       func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
          
           let userInfo = response.notification.request.content.userInfo
           
           //let identifier = response.notification.request.identifier
           
           let gcmMessageID = userInfo["gcm.message_id"] as? String ?? ""
           

           CoreDataManager.shared.updateNotificationStatus(byMessageID: gcmMessageID, newStatus: "READ")

          
           PaylisherSDK.shared.capture("notificationOpen")
           
           print("FCM -> didReceive")
           print("Bildirime tıklandı.")
           
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
