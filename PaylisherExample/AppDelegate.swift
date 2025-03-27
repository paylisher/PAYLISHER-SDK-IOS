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
//import CoreData

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate  {
    
    
 
    /* func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
       
    
    
    }*/
    
   

 

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launcOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool{

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
        
    
        
        let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        
        config.windowScene = windowScene
        
       
        
    
        
        
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
    

      var processedNotifications = Set<String>()
      func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
          
          let userInfo = notification.request.content.userInfo
         
          let notificationID = notification.request.identifier
          
          //let request = notification.request
          
         if processedNotifications.contains(notificationID) {
              print("Tekrarlanan bildirim algılandı, işlenmiyor.")
              return
          }
          processedNotifications.insert(notificationID)
          print("Bildirim ID’si: \(notificationID) - İşleniyor.")
    
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
      
   //       let windowScene: UIWindowScene? = nil
          
         
          
    NotificationManager.shared.customNotification(
        windowScene: windowScene,
          userInfo: userInfo,
          mutableContent,
        notification.request,
          { content in
                 
              
                  //   completionHandler([.banner, .sound])
         }
        
        
        
      )
        
    
          print("FCM -> willPresents")
      //    print(userInfo)
          
          PaylisherSDK.shared.capture("notificationReceived")//Normalde bu eventin bu fonksiyon altında yazılmaması gerekiyor çünkü bu fonksiyon uygulama ön plandayken bildirim geldiğinde aktif oluyor yani uygulama arka plandayken bildirim geldiğinde event gönderilmiyor. Aklında bulunsun, sonra düzelt.
         
          completionHandler([.sound, .list, .banner, .badge ])
       }

    
       func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
           
          
           
           let userInfo = response.notification.request.content.userInfo
           
           let identifier = response.notification.request.identifier
           
           CoreDataManager.shared.updateNotificationStatus(byIdentifier: identifier, newStatus: "READ")
          
           PaylisherSDK.shared.capture("notificationOpen")
           
           print("FCM -> didReceive")
           
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
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        let state = UIApplication.shared.applicationState
            
            if state == .active {
                // Uygulama ön planda ise hiçbir şey yapmadan hemen completion çağır
                print("Sessiz push geldi ama uygulama ön planda, işleme almıyorum.")
                completionHandler(.noData)
                return
            }else {
                
                let type = userInfo["type"] as? String ?? ""
                
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
                    
                case "SILENT":
                    
                    print("Sessiz push alındı: \(userInfo)")
                        
                        // displayTime değeri payload'dan alınır (örneğin milisaniye cinsinden string)
                        if let displayTimeString = userInfo["displayTime"] as? String,
                           let displayTimeMillis = Double(displayTimeString) {
                            
                            let displayDate = Date(timeIntervalSince1970: displayTimeMillis / 1000)
                            print("Planlanacak tarih: \(displayDate)")
                            scheduleLocalNotification(at: displayDate, userInfo: userInfo)
                        } else {
                            print("displayTime verisi yok ya da dönüştürülemiyor")
                        }
                        
                        completionHandler(.newData)
               
                
                default:
                    print("defffaaauuullttt")
                }
                
            }

    }
    
    func scheduleLocalNotification(at date: Date, userInfo: [AnyHashable: Any]) {
            let content = UNMutableNotificationContent()
            content.title = userInfo["title"] as? String ?? ""
            content.body = userInfo["message"] as? String ?? ""
            
        let silent = userInfo["silent"] as? String ?? ""
        
        if silent == "true" {
            content.sound = nil
        }else{
            content.sound = UNNotificationSound.default
        }
          
            content.userInfo = userInfo
             
            

            if let imageUrlString = userInfo["imageUrl"] as? String,
               let imageURL = URL(string: imageUrlString) {
                addImageAttachment(from: imageURL, to: content) { updatedContent in
                    self.scheduleNotification(with: updatedContent, at: date)
                }
            } else {
                self.scheduleNotification(with: content, at: date)
            }
        }

        private func scheduleNotification(with content: UNMutableNotificationContent, at date: Date) {
            let triggerDate = Calendar.current.dateComponents(in: TimeZone.current, from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Local notification planlanırken hata: \(error)")
                } else {
                    print("Local notification planlandı: \(date)")
                }
            }
        }
    
    func addImageAttachment(from imageUrl: URL, to content: UNMutableNotificationContent, completion: @escaping (UNMutableNotificationContent) -> Void) {
        URLSession.shared.downloadTask(with: imageUrl) { localURL, response, error in
            print("Görsel İndirme Tamamlandı. localURL: \(String(describing: localURL)), error: \(String(describing: error))")
            
            if let localURL = localURL {
                do {
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let tempFileURL = tempDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    
                    try FileManager.default.moveItem(at: localURL, to: tempFileURL)
                    
                    // Attachment seçenekleri, kUTTypeJPEG kullandığımız için JPEG olduğunu belirtiyoruz.
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


}
