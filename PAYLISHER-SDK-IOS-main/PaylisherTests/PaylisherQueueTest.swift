//
//  PaylisherQueueTest.swift
//  PaylisherTests
//
//  Created by Manoel Aranda Neto on 30.10.23.
//

import Foundation
import Nimble
@testable import Paylisher
import Quick
import XCTest

class PaylisherQueueTest: QuickSpec {
    func getSut(flushAt: Int = 1, maxQueueSize: Int = 1000) -> PaylisherQueue {
        let config = PaylisherConfig(apiKey: "123", host: "http://localhost:9001")
        config.flushAt = flushAt
        config.maxQueueSize = maxQueueSize
        let storage = PaylisherStorage(config)
        let api = PaylisherApi(config)
        return PaylisherQueue(config, storage, api, .batch, nil)
    }

    override func spec() {
        var server: MockPaylisherServer!

        beforeEach {
            server = MockPaylisherServer()
            server.start()
        }
        afterEach {
            server.stop()
        }

        it("add item to queue") {
            let sut = self.getSut()

            let event = PaylisherEvent(event: "event", distinctId: "distinctId")
            sut.add(event)

            expect(sut.depth) == 1

            let events = getBatchedEvents(server)
            expect(events.count) == 1

            expect(sut.depth) == 0

            sut.clear()
        }

        it("add item to queue and flush respecting flushAt") {
            let sut = self.getSut()

            let event = PaylisherEvent(event: "event", distinctId: "distinctId")
            let event2 = PaylisherEvent(event: "event2", distinctId: "distinctId2")
            sut.add(event)
            sut.add(event2)

            expect(sut.depth) == 2

            let events = getBatchedEvents(server)
            expect(events.count) == 1

            expect(sut.depth) == 1

            sut.clear()
        }

        it("add item to queue and rotate queue") {
            let sut = self.getSut(flushAt: 3, maxQueueSize: 2)

            let event = PaylisherEvent(event: "event", distinctId: "distinctId")
            let event2 = PaylisherEvent(event: "event2", distinctId: "distinctId2")
            let event3 = PaylisherEvent(event: "event3", distinctId: "distinctId3")
            sut.add(event)
            sut.add(event2)
            sut.add(event3)

            expect(sut.depth) == 2

            sut.flush()

            let events = getBatchedEvents(server)

            expect(events.count) == 2

            let first = events.first!
            let last = events.last!
            expect(first.event) == "event2"
            expect(last.event) == "event3"

            sut.clear()
        }
    }
}
