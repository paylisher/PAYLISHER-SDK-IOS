//
//  PaylisherStorageManagerTest.swift
//  PaylisherTests
//
//  Created by Ben White on 22.03.23.
//

import Foundation
import Nimble
@testable import Paylisher
import Quick

class PaylisherStorageManagerTest: QuickSpec {
    func getSut() -> PaylisherStorageManager {
        let config = PaylisherConfig(apiKey: "123")
        return PaylisherStorageManager(config)
    }

    override func spec() {
        it("Generates an anonymousId") {
            let sut = self.getSut()

            let anonymousId = sut.getAnonymousId()
            expect(anonymousId) != nil
            let secondAnonymousId = sut.getAnonymousId()
            expect(secondAnonymousId) == anonymousId

            sut.reset(true)
        }

        it("Uses the anonymousId for distinctId if not set") {
            let sut = self.getSut()

            let anonymousId = sut.getAnonymousId()
            let distinctId = sut.getDistinctId()
            expect(distinctId) == anonymousId

            let idToSet = UUID.v7().uuidString
            sut.setDistinctId(idToSet)
            let newAnonymousId = sut.getAnonymousId()
            let newDistinctId = sut.getDistinctId()
            expect(newAnonymousId) == anonymousId
            expect(newAnonymousId) != newDistinctId
            expect(newDistinctId) == idToSet

            sut.reset(true)
        }

        it("Can can accept id customization via config") {
            let config = PaylisherConfig(apiKey: "123")
            let fixedUuid = UUID.v7()
            config.getAnonymousId = { _ in fixedUuid }
            let sut = PaylisherStorageManager(config)
            let anonymousId = sut.getAnonymousId()
            expect(anonymousId) == fixedUuid.uuidString

            sut.reset(true)
        }
    }
}
