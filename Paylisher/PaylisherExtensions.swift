//
//  PaylisherExtensions.swift
//  Paylisher
//
//  Created by Manoel Aranda Neto on 13.10.23.
//

import Foundation

/**
 # Notifications

 This helper module encapsulates all notifications that we trigger from within the SDK.

 */

public extension PaylisherSDK {
    @objc static let didStartNotification = Notification.Name("PaylisherDidStart") // object: nil
    @objc static let didReceiveFeatureFlags = Notification.Name("PaylisherDidReceiveFeatureFlags") // object: nil
}
