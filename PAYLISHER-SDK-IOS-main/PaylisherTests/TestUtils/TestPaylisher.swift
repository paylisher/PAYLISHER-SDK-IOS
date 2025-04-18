//
//  TestPaylisher.swift
//  PaylisherTests
//
//  Created by Ben White on 22.03.23.
//

import Foundation
import Paylisher
import XCTest

func getBatchedEvents(_ server: MockPaylisherServer, timeout: TimeInterval = 15.0, failIfNotCompleted: Bool = true) -> [PaylisherEvent] {
    let result = XCTWaiter.wait(for: [server.batchExpectation!], timeout: timeout)

    if result != XCTWaiter.Result.completed, failIfNotCompleted {
        XCTFail("The expected requests never arrived")
    }

    var events: [PaylisherEvent] = []
    for request in server.batchRequests.reversed() {
        let items = server.parsePaylisherEvents(request)
        events.append(contentsOf: items)
    }

    return events
}

func waitDecideRequest(_ server: MockPaylisherServer) {
    let result = XCTWaiter.wait(for: [server.decideExpectation!], timeout: 15)

    if result != XCTWaiter.Result.completed {
        XCTFail("The expected requests never arrived")
    }
}

func getDecideRequest(_ server: MockPaylisherServer) -> [[String: Any]] {
    waitDecideRequest(server)

    var requests: [[String: Any]] = []
    for request in server.decideRequests.reversed() {
        let item = server.parseRequest(request, gzip: false)
        requests.append(item!)
    }

    return requests
}
