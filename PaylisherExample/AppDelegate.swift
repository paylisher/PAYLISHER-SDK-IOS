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
    
    func application(_ application: UIApplication,
       didReceiveRemoteNotification userInfo: [AnyHashable : Any],
       fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("Arka planda bildirim alındı")
     
    }

      var processedNotifications = Set<String>()
      func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
           
          
          
          let userInfo = notification.request.content.userInfo
          
        
          
          let notificationID = notification.request.identifier

         
          if processedNotifications.contains(notificationID) {
              print("Tekrarlanan bildirim algılandı, işlenmiyor.")
              return
          }
          
          PaylisherNativeInAppNotificationManager.shared.nativeInAppNotification(userInfo: userInfo)
          
          //PaylisherCustomInAppNotificationManager.shared.customInAppFunction(userInfo: userInfo)
          
          PaylisherCustomInAppNotificationManager.shared.parseInAppPayload(from: userInfo)
          
          PaylisherCustomInAppNotificationManager.shared.customInAppFunction(userInfo: userInfo)

          
          processedNotifications.insert(notificationID)
          print("Bildirim ID’si: \(notificationID) - İşleniyor.")
          
          print("test -> willPresents")
          
          PaylisherSDK.shared.capture("notificationReceived")//Normalde bu eventin bu fonksiyon altında yazılmaması gerekiyor çünkü bu fonksiyon uygulama ön plandayken bildirim geldiğinde aktif oluyor yani uygulama arka plandayken bildirim geldiğinde event gönderilmiyor. Aklında bulunsun, sonra düzelt.
         
          completionHandler([.sound, .list, .banner, .badge ])
       }

       func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
           
           let userInfo = response.notification.request.content.userInfo
           
           let identifier = response.notification.request.identifier
           
           CoreDataManager.shared.updateNotificationStatus(byIdentifier: identifier, newStatus: "READ")
           
           PaylisherSDK.shared.capture("notificationOpen")
         
           if let actionURLString = userInfo["action"] as? String,
              let actionURL = URL(string: actionURLString) {
               print("Bildirime tıklandı, açılan URL: \(actionURL)")
               UIApplication.shared.open(actionURL, options: [:], completionHandler: nil)
           } else {
               print("Action URL bulunamadı!")
           }
           
           completionHandler()
  
       }
    
    /*public func xustomInAppFunction(userInfo: [AnyHashable: Any]) {
        
        guard let payload = PaylisherCustomInAppNotificationManager.shared.parseInAppPayload(from: userInfo) else {
            print("Payload parse edilemedi.")
            return
        }
        
        let lang = payload.defaultLang ?? "en"
      //  let layoutType = payload.layoutType ?? "no-type"
       // print("Default Lang:", lang)
       // print("Layout Type:", layoutType)
        
        
        if let layouts = payload.layouts, !layouts.isEmpty {
            let firstLayout = layouts[0]
            
            
            
            print("--------------Style---------------")
            
            if let style = firstLayout.style, let close = firstLayout.close {
                print("navigationalArrows: ", style.navigationalArrows ?? "")
                print("radius: ", style.radius ?? "")
                print("bgColor: ", style.bgColor ?? "")
                print("bgImage: ", style.bgImage ?? "")
                print("bgImageMask: ", style.bgImageMask ?? "")
                print("bgImageColor: ", style.bgImageColor ?? "")
                print("verticalPosition: ", style.verticalPosition ?? "")
                print("horizontalPosition: ", style.horizontalPosition ?? "boş")
                print("active: ", close.active ?? "")
                
                let styleVC = StyleViewController(style: style, close: close, defaultLang: lang)
                styleVC.modalPresentationStyle = .overFullScreen
                        
                        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                            rootVC.present(styleVC, animated: true)
                        }
            }
            
            
            
            print("----------------------------------")
            print("--------------Close---------------")
            
            if let close = firstLayout.close {
               // print("active: ", close.active ?? "")
                print("type: ", close.type ?? "")
                print("position: ", close.position ?? "")
                print("iconColor: ", close.icon?.color ?? "")
                print("iconStyle: ", close.icon?.style ?? "")
                print("textLabel: ", close.text?.label![lang] ?? "")
                print("textFontSize: ", close.text?.fontSize ?? "")
                print("textColor: ", close.text?.color ?? "")
                
            }
            
            print("----------------------------------")
            print("--------------Extra---------------")
            
            if let extra = firstLayout.extra {
                
                print("transition: ", extra.transition ?? "")
                print("bannerAction: ", extra.banner?.action ?? "")
                print("bannerDuration: ", extra.banner?.duration ?? "")
                print("overlayAction: ", extra.overlay?.action ?? "")
                print("overlayColor: ", extra.overlay?.color ?? "")
                
            }
            
            print("----------------------------------")
            print("--------------Blocks---------------")
            
            if let blocks = firstLayout.blocks {
                print("blocksLayer:", blocks.align ?? "")
                
                if let blockArray = blocks.order {
                    for block in blockArray {
                        switch block {
                        case .image(let imageBlock):
                            
                            print("--------------Image Block---------------")
                            print("typeImage: ", imageBlock.type ?? "")
                            print("orderImage: ", imageBlock.order ?? "")
                            print("urlImage: ", imageBlock.url ?? "")
                            print("altImage: ", imageBlock.alt ?? "")
                            print("linkImage: ", imageBlock.link ?? "boş")
                            print("radiusImage: ", imageBlock.radius ?? "")
                            print("marginImage: ", imageBlock.margin ?? "")
                            
                            
                        case .spacer(let spacerBlock):
                            
                            print("----------------------------------")
                            print("--------------Spacer Block---------------")
                            print("typeSpacer: ", spacerBlock.type ?? "")
                            print("orderSpacer: ", spacerBlock.order ?? "")
                            print("verticalSpacingSpacer: ", spacerBlock.verticalSpacing ?? "")
                            print("fillAvailableSpacingSpacer: ", spacerBlock.fillAvailableSpacing ?? "")
                            
                            
                        case .text(let textBlock):
                            print("----------------------------------")
                            print("--------------Text Block---------------")
                            print("typeText: ", textBlock.type ?? "")
                            print("orderText: ", textBlock.order ?? "")
                            print("contentText: ", textBlock.content![lang]!)
                            print("actionText: ", textBlock.action ?? "")
                            print("fontFamilyText: ", textBlock.fontFamily ?? "")
                            print("fontWeightText: ", textBlock.fontWeight ?? "")
                            print("fontSizeText: ", textBlock.fontSize ?? "")
                            print("underscoreText: ", textBlock.underscore ?? "")
                            print("italicText: ", textBlock.italic ?? "")
                            print("colorText: ", textBlock.color ?? "")
                            print("textAlignmentText: ", textBlock.textAlignment ?? "")
                            print("horizontalMarginText: ", textBlock.horizontalMargin ?? "")
                            
                            
                        case .buttonGroup(let buttonGroupBlock):
                            print("----------------------------------")
                            print("--------------ButtonGroup Block---------------")
                            print("typeButtonGroup: ", buttonGroupBlock.type ?? "")
                            print("orderButtonGroup: ", buttonGroupBlock.order ?? "")
                            print("buttonGroupTypeButtonGroup: ", buttonGroupBlock.buttonGroupType ?? "")
                            
                            if let buttonsArray = buttonGroupBlock.buttons{
                                
                                for button in buttonsArray {
                                    
                                    print("labelButtonGroup: ", button.label![lang]!)
                                    print("actionButtonGroup: ", button.action ?? "")
                                    print("fontFamilyButtonGroup: ", button.fontFamily ?? "")
                                    print("fontWeightButtonGroup: ", button.fontWeight ?? "")
                                    print("fontSizeButtonGroup: ", button.fontSize ?? "")
                                    print("underscoreButtonGroup: ", button.underscore ?? "")
                                    print("italicButtonGroup: ", button.italic ?? "")
                                    print("textColorButtonGroup: ", button.textColor ?? "")
                                    print("backgroundColorButtonGroup: ", button.backgroundColor ?? "")
                                    print("borderColorButtonGroup: ", button.borderColor ?? "")
                                    print("borderRadiusButtonGroup: ", button.borderRadius ?? "")
                                    print("horizontalSizeButtonGroup: ", button.horizontalSize ?? "")
                                    print("verticalSizeButtonGroup: ", button.verticalSize ?? "")
                                    print("buttonPositionButtonGroup: ", button.buttonPosition ?? "")
                                    print("marginButtonGroup: ", button.margin ?? "")
                                    print("----------------------------------")
                                }
                            }
                        }
                    }
                }
            }

            
        }
    
       
        }*/
        
    
       
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
