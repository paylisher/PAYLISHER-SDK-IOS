//
//  PaylisherExampleWatchOSApp.swift
//  PaylisherExampleWatchOS Watch App
//
//  Created by Manoel Aranda Neto on 02.11.23.
//

import Paylisher
import SwiftUI

@main
struct PaylisherExampleWatchOSApp: App {
    init() {
        // TODO: init on app delegate instead
        let config = PaylisherConfig(
            apiKey: "phc_QFbR1y41s5sxnNTZoyKG2NJo2RlsCIWkUfdpawgb40D"
        )

        PaylisherSDK.shared.setup(config)
        PaylisherSDK.shared.debug()
        PaylisherSDK.shared.capture("Event from WatchOS example!")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
