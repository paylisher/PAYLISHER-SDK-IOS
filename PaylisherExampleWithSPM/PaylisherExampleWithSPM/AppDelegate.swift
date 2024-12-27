//
//  AppDelegate.swift
//  PaylisherExampleWithPods
//
//  Created by Manoel Aranda Neto on 24.10.23.
//
import Foundation
import Paylisher
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let defaultCenter = NotificationCenter.default

        defaultCenter.addObserver(self,
                                  selector: #selector(receiveFeatureFlags),
                                  name: PaylisherSDK.didReceiveFeatureFlags,
                                  object: nil)

        let config = PaylisherConfig(
            apiKey: "phc_QFbR1y41s5sxnNTZoyKG2NJo2RlsCIWkUfdpawgb40D"
        )

        PaylisherSDK.shared.setup(config)
        PaylisherSDK.shared.debug()
        PaylisherSDK.shared.capture("Event from SPM example!")

        return true
    }

    @objc func receiveFeatureFlags() {
        print("receiveFeatureFlags")
    }
}
