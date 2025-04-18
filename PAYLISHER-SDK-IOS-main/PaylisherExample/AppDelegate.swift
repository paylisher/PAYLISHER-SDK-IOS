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

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate  {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launcOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool{

        let PAYLISHER_API_KEY = "<phc_test>"
        let PAYLISHER_HOST = "<https://test.paylisher.com>"

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
                   
       
       
        let myTesty = Testy(test: "Hello", title: "World")
        let dd = sdfghjnm.dgj()
        
        PaylisherSDK.shared.setup_test(config)
        PaylisherSDK.shared.setup(config)
        
        
//        PaylisherSDK.shared.debug()
        PaylisherSDK.shared.capture("App started!")
//        PaylisherSDK.shared.reset()


        PaylisherSDK.shared.capture(
           "Person",
           userProperties : ["Email": "ios@test.com", "Username": "iOS"]
        )

        //        PaylisherSDK.shared.identify("TEST-iOS")
                 
        PaylisherSDK.shared.identify( "Test-iOS",
            userProperties :["name": "Paylisher iOS", "email": "ios@test.com"],
            userPropertiesSetOnce : ["date_of_first_log_in": "2024-03-01"]
        )

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
           
           completionHandler([[.banner, .list, .sound]])
       }
       
       func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
           
           let userInfo = response.notification.request.content.userInfo
           
           NotificationCenter.default.post(name: Notification.Name("didReceiveRemoteNotification"), object: nil, userInfo: userInfo)
           completionHandler()
           
       }
       
       @objc func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
           
           messaging.token{ token, _ in
               guard let token = token else{
                   return
               }
               print("token: \(token)")
           }
       }
}
