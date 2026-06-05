//
//  PaylisherRepeatedIdentifyBehavior.swift
//  Paylisher
//

import Foundation

/// Controls what happens when `identify()` is called again with the same distinctId
/// after the user is already identified on the current device.
@objc(PaylisherRepeatedIdentifyBehavior) public enum PaylisherRepeatedIdentifyBehavior: Int {
    /// Preserve the legacy behavior and suppress duplicate identify calls.
    case ignore

    /// Emit a new `$identify` event so person/device properties can be refreshed.
    case capture
}
