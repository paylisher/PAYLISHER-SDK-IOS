//
//  Errors.swift
//  Paylisher
//
//  Created by Ben White on 21.03.23.
//

import Foundation

struct InternalPaylisherError: Error, CustomStringConvertible {
    let description: String

    init(description: String, fileID: StaticString = #fileID, line: UInt = #line) {
        self.description = "\(description) (\(fileID):\(line))"
    }
}

struct FatalPaylisherError: Error, CustomStringConvertible {
    let description: String

    init(description: String, fileID: StaticString = #fileID, line: UInt = #line) {
        self.description = "Fatal Paylisher error: \(description) (\(fileID):\(line))"
    }
}
