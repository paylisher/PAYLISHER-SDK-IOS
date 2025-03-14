//
//  PaylisherConfigTest.swift
//  PaylisherTests
//
//  Created by Manoel Aranda Neto on 30.10.23.
//

import Foundation
import Nimble
@testable import Paylisher
import Quick

class PaylisherConfigTest: QuickSpec {
    override func spec() {
        it("init config with default values") {
            let config = PaylisherConfig(apiKey: "123")

            expect(config.host) == URL(string: PaylisherConfig.defaultHost)
            expect(config.flushAt) == 20
            expect(config.maxQueueSize) == 1000
            expect(config.maxBatchSize) == 50
            expect(config.flushIntervalSeconds) == 30
            expect(config.dataMode) == .any
            expect(config.sendFeatureFlagEvent) == true
            expect(config.preloadFeatureFlags) == true
            expect(config.captureApplicationLifecycleEvents) == true
            expect(config.captureScreenViews) == true
            expect(config.debug) == false
            expect(config.optOut) == false
        }

        it("init takes api key") {
            let config = PaylisherConfig(apiKey: "123")

            expect(config.apiKey) == "123"
        }

        it("init takes host") {
            let config = PaylisherConfig(apiKey: "123", host: "localhost:9000")

            expect(config.host) == URL(string: "localhost:9000")!
        }
    }
}
