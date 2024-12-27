//
//  PaylisherExampleMacOSApp.swift
//  PaylisherExampleMacOS
//
//  Created by Manoel Aranda Neto on 10.11.23.
//

import SwiftUI

@main
struct PaylisherExampleMacOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
