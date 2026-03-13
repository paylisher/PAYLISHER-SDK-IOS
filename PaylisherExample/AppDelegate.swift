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
    
    // MARK: - Deep Link Navigation Publisher
    /// ContentView bu publisher'ı dinleyerek navigation yapacak
    static let deepLinkNavigationPublisher = PassthroughSubject<String, Never>()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launcOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool{

        //let PAYLISHER_API_KEY = "phc_JwUJI7MmnWguE6e211Ah0WMtedBQELE" // "<phc_test>"
        //let PAYLISHER_HOST = "https://analytics.paylisher.com" //"<https://test.paylisher.com>"
        //Diyetim Prod
        //let PAYLISHER_API_KEY = "phc_zBfUgXiUDyWfnKofkz781HbmgD1H4C3q7U1tJpuF0Wj"
        //let PAYLISHER_HOST = "https://ds.paylisher.com"
        
        let PAYLISHER_API_KEY = "phc_3wZe1GW8GRdeUGQK0LqaS25PEDUNS9EBSxe7FiQFqQW"
        let PAYLISHER_HOST = "https://ds-tr.paylisher.com"
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

        // Deferred Deep Link Config
        config.deferredDeepLinkConfig = PaylisherDeferredDeepLinkConfig()
        config.deferredDeepLinkConfig?.enabled = true
        config.deferredDeepLinkConfig?.debugLogging = true
        config.deferredDeepLinkConfig?.autoHandleDeepLink = true
        config.deferredDeepLinkConfig?.includeIDFA = false // Test için IDFA kapalı

        PaylisherSDK.shared.setup(config)

        // ============================================
        // MARK: - Deferred Deep Link Check
        // ============================================

        // İlk açılışta deferred deep link kontrolü yap
        PaylisherSDK.shared.checkDeferredDeepLink(
            onSuccess: { deepLink in
                print("✅ [Deferred] Match found! URL: \(deepLink.url)")
                print("✅ [Deferred] Destination: \(deepLink.destination)")
                if let jid = deepLink.jid {
                    print("✅ [Deferred] Journey ID: \(jid)")
                }
                // SDK otomatik olarak "Deferred Deep Link Matched" event'ini gönderir
                // autoHandleDeepLink = true ise otomatik navigate eder
            },
            onNoMatch: {
                print("ℹ️ [Deferred] No match found (organic install)")
            },
            onError: { error in
                print("❌ [Deferred] Error: \(error.localizedDescription)")
            }
        )

        // ============================================
        // MARK: - Deep Link SDK Kurulumu
        // ============================================
        
        // Auth gerektiren sayfaları tanımla
        PaylisherSDK.shared.configureDeepLinks(authRequired: [
            "wallet",
            "transfer",
            "profile",
            "settings",
            "payment"
            // "yeniSayfa" ve "crashTest" auth gerektirmiyor
        ])
        
        // Debug logging aç (geliştirme için)
        PaylisherDeepLinkManager.shared.config.debugLogging = true
        
        // Deep link handler olarak kendimizi ayarla
        PaylisherSDK.shared.setDeepLinkHandler(self)
        
        // ============================================
  
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
        
        PaylisherSDK.shared.capture("App started!")

        // identify() artık ContentView'deki buton ile test ediliyor

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
    
    // ============================================
    // MARK: - Deep Link URL Handling
    // ============================================
    
    /// URL Scheme ile gelen deep linkler (iOS 12 ve altı, veya SceneDelegate yoksa)
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("📱 AppDelegate: Deep link alındı - \(url)")
        return PaylisherSDK.shared.handleDeepLink(url)
    }
    
    /// Universal Link ile gelen deep linkler
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        print("📱 AppDelegate: Universal link alındı")
        return PaylisherSDK.shared.handleUserActivity(userActivity)
    }

    // ============================================

    @objc func receiveFeatureFlags() {
        print("user receiveFeatureFlags callback")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("FCM application -> didRegisterForRemoteNotificationsWithDeviceToken")
        Messaging.messaging().apnsToken = deviceToken
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("FCM -> willPresents")
        PaylisherSDK.shared.capture("notificationReceived")
        completionHandler([.sound, .list, .banner, .badge ])
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        // Paylisher silent heartbeat check – if handled, return early
        if PaylisherSDK.shared.handleSilentPush(userInfo, completionHandler: completionHandler) {
            return
        }
        
        // Existing notification handling for non-heartbeat pushes
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
     
        NotificationManager.shared.customNotification(windowScene: windowScene, userInfo: userInfo, content, request, {
            content in
        })
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let gcmMessageID = userInfo["gcm.message_id"] as? String ?? ""

        PaylisherSDK.shared.capture("notificationOpen")

        print("FCM -> didReceive")
        print("Bildirime tıklandı.")

        if let actionURLString = userInfo["action"] as? String,
           let actionURL = URL(string: actionURLString) {
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

            // Register FCM token with Paylisher SDK for heartbeat / uninstall detection
            PaylisherSDK.shared.registerFCMToken(token)
        }
    }
}

// ============================================
// MARK: - Deep Link Handler Protocol
// ============================================

extension AppDelegate: PaylisherDeepLinkHandler {
    
    /// Deep link alındığında çağrılır
    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        print("📱 Deep link alındı: \(deepLink.destination), auth gerekli: \(requiresAuth)")

        // ✅ SDK otomatik olarak jid'yi extract edip set etti (PaylisherDeepLinkManager)
        // ✅ SDK otomatik olarak "Deep Link Opened" event'ini gönderdi (captureDeepLinkEvent)
        // ✅ Tüm sonraki eventler otomatik olarak jid içerecek (buildProperties)

        if let jid = deepLink.jid {
            print("✅ [Journey] Campaign deep link - jid: \(jid)")
        } else {
            print("ℹ️ [Journey] Organic deep link (no jid)")
        }

        if requiresAuth {
            // Auth gerekiyorsa, pending olarak beklet
            // Login sonrası completePendingDeepLink() çağrılmalı
            print("⚠️ Auth gerekli, kullanıcı giriş yapmalı")
        } else {
            // Auth gerekmiyorsa direkt navigate et
            navigateToDestination(deepLink.destination)
        }
    }
    
    /// Auth gerektiğinde çağrılır (opsiyonel)
    func paylisherDeepLinkRequiresAuth(_ deepLink: PaylisherDeepLink, completion: @escaping (Bool) -> Void) {
        print("🔐 Auth gerekli: \(deepLink.destination)")
        
        let authManager = FakeAuthManager.shared
        
        if authManager.isAuthenticated {
            print("✅ User already authenticated")
            completion(true)
        } else {
            print("❌ User not authenticated, show login")
            authManager.setPendingDeepLink(destination: deepLink.destination)
            
            DispatchQueue.main.async {
                AppDelegate.deepLinkNavigationPublisher.send("LoginView")
            }
            completion(false)
        }
    }
    
    /// Deep link parse hatası olduğunda çağrılır (opsiyonel)
    func paylisherDeepLinkDidFail(_ url: URL, error: Error?) {
        print("❌ Deep link hatası: \(url), error: \(error?.localizedDescription ?? "unknown")")
    }
    
    // MARK: - Navigation Helper

    /// Destination'a göre navigate et
    private func navigateToDestination(_ destination: String) {
        print("🚀 Navigating to: \(destination)")

        // ✅ Track navigation (jid otomatik eklenir - SDK buildProperties)
        PaylisherSDK.shared.capture("Deep Link Navigation", properties: [
            "destination": destination,
            "navigation_category": "deeplink"
        ])

        // Destination mapping
        let viewName: String
        switch destination {
        case "yeniSayfa":
            viewName = "YeniSayfaView"
        case "crashTest":
            viewName = "CrashTestView"
        default:
            viewName = destination
        }

        // Publisher ile ContentView'a bildir
        DispatchQueue.main.async {
            AppDelegate.deepLinkNavigationPublisher.send(viewName)
        }
    }
}
