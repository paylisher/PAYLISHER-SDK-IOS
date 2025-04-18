import Cocoa
import Paylisher

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        let config = PaylisherConfig(
            apiKey: "phc_QFbR1y41s5sxnNTZoyKG2NJo2RlsCIWkUfdpawgb40D"
        )
        config.debug = true

        PaylisherSDK.shared.setup(config)
//        PaylisherSDK.shared.capture("Event from MacOS example!")
    }

    func applicationWillTerminate(_: Notification) {
        // Insert code here to tear down your application
    }
}
