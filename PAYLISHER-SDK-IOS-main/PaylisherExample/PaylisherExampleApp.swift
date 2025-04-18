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
        }
    }
}
