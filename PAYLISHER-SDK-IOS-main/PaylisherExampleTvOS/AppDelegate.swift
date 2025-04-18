import Paylisher
import SwiftUI
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let config = PaylisherConfig(
            apiKey: "phc_QFbR1y41s5sxnNTZoyKG2NJo2RlsCIWkUfdpawgb40D"
        )
        config.debug = true

        PaylisherSDK.shared.setup(config)
        PaylisherSDK.shared.capture("Event from TvOS example!")

        return true
    }
}
