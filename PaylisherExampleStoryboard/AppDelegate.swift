//
//  AppDelegate.swift
//  PaylisherExampleStoryboard
//
//  Created by Manoel Aranda Neto on 21.03.24.
//

import Paylisher
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let config = PaylisherConfig(
            apiKey: "phc_QFbR1y41s5sxnNTZoyKG2NJo2RlsCIWkUfdpawgb40D"
        )
        // the ScreenViews for SwiftUI does not work, the names are not useful
        config.captureScreenViews = false
        config.captureApplicationLifecycleEvents = false
//        config.flushAt = 1
//        config.flushIntervalSeconds = 30
        config.debug = true
        config.sendFeatureFlagEvent = false
        config.sessionReplay = true
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.screenshotMode = true
        config.sessionReplayConfig.maskAllImages = true
        config.sessionReplayConfig.captureNetworkTelemetry = true

        PaylisherSDK.shared.setup(config)

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options _: UIScene.ConnectionOptions) -> UISceneConfiguration
    {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
