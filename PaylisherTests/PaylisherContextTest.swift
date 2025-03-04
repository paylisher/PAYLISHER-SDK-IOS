//
//  PaylisherContextTest.swift
//  PaylisherTests
//
//  Created by Manoel Aranda Neto on 30.10.23.
//

import Foundation
import Nimble
@testable import Paylisher
import Quick

class PaylisherContextTest: QuickSpec {
    func getSut() -> PaylisherContext {
        #if !os(watchOS)
            var reachability: Reachability?
            do {
                reachability = try Reachability()
            } catch {
                // ignored
            }
            return PaylisherContext(reachability)
        #else
            return PaylisherContext()
        #endif
    }

    override func spec() {
        it("returns static context") {
            let sut = self.getSut()

            let context = sut.staticContext()
            expect(context["$app_name"] as? String) == "xctest"
            expect(context["$app_version"] as? String) != nil
            expect(context["$app_build"] as? String) != nil
            expect(context["$app_namespace"] as? String) == "com.apple.dt.xctest.tool"
            expect(context["$is_emulator"] as? Bool) != nil
            #if os(iOS) || os(tvOS)
                expect(context["$device_name"] as? String) != nil
                expect(context["$os_name"] as? String) != nil
                expect(context["$os_version"] as? String) != nil
                expect(context["$device_type"] as? String) != nil
                expect(context["$device_model"] as? String) != nil
                expect(context["$device_manufacturer"] as? String) == "Apple"
            #endif
        }

        it("returns dynamic context") {
            let sut = self.getSut()

            let context = sut.dynamicContext()

            #if os(iOS) || os(tvOS)
                expect(context["$screen_width"] as? Float) != nil
                expect(context["$screen_height"] as? Float) != nil
            #endif
            expect(context["$locale"] as? String) != nil
            expect(context["$timezone"] as? String) != nil
            expect(context["$network_wifi"] as? Bool) != nil
            expect(context["$network_cellular"] as? Bool) != nil
        }

        it("returns sdk info") {
            let sut = self.getSut()

            let context = sut.sdkInfo()

            expect(context["$lib"] as? String) == "paylisher-ios"
            expect(context["$lib_version"] as? String) == paylisherVersion
        }
    }
}
