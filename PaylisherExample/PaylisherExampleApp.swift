//
//  PaylisherExampleApp.swift
//  PaylisherExample
//
//  Created by Ben White on 10.01.23.
//

import SwiftUI

@main
struct PaylisherExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .paylisherScreenView() // will infer the class name (ContentView)
            
            // NOT: Deep link handling ContentView içindeki .onOpenURL ile yapılıyor
            // SDK kullanımı:
            // 1. AppDelegate'de PaylisherSDK.shared.configureDeepLinks() çağrılıyor
            // 2. AppDelegate PaylisherDeepLinkHandler protocol'ünü implement ediyor
            // 3. ContentView'da .onOpenURL içinde PaylisherSDK.shared.handleDeepLink(url) çağrılıyor
            // 4. SDK otomatik olarak "Deep Link Opened" eventi gönderiyor
            // 5. AppDelegate'deki handler çağrılıyor ve navigation yapılıyor
        }
    }
}
