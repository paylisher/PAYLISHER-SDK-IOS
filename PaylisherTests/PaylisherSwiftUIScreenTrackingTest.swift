//
//  PaylisherSwiftUIScreenTrackingTest.swift
//  PaylisherTests
//
//  Created by Codex on 13.03.26.
//

import Foundation
import Nimble
import Quick
#if canImport(SwiftUI)
    import SwiftUI
#endif

#if os(iOS) || os(tvOS)
    import UIKit
    @testable import Paylisher

    class PaylisherSwiftUIScreenTrackingTest: QuickSpec {
        override func spec() {
            beforeEach {
                UIViewController.resetAutoScreenCaptureDedupeState()
            }

            afterEach {
                UIViewController.resetAutoScreenCaptureDedupeState()
            }

            it("returns nil for placeholder SwiftUI type Content") {
                let inferredName = UIViewController.extractSwiftUIViewName(
                    from: "UIHostingController<Content>"
                )

                expect(inferredName).to(beNil())
            }

            it("keeps View suffix for ContentView type") {
                let inferredName = UIViewController.extractSwiftUIViewName(
                    from: "UIHostingController<ContentView>"
                )

                expect(inferredName) == "ContentView"
            }

            it("extracts nested custom SwiftUI view name") {
                let inferredName = UIViewController.extractSwiftUIViewName(
                    from: "UIHostingController<ModifiedContent<CheckoutView, _TraitWritingModifier<Optional<LocalizedStringKey>>>>"
                )

                expect(inferredName) == "CheckoutView"
            }

            it("prefers explicit title over parsed SwiftUI type") {
                let viewController = UIViewController()
                viewController.title = "Checkout Screen"

                let name = UIViewController.getViewControllerName(
                    viewController,
                    className: "UIHostingController<Content>"
                )

                expect(name) == "Checkout Screen"
            }

            it("dedupes repeated auto screen names in a short interval") {
                let baseTime = Date(timeIntervalSince1970: 1000)
                let viewController = UIViewController()

                let firstCapture = UIViewController.shouldCaptureAutoScreenView("ContentView", from: viewController, at: baseTime)
                let duplicateCapture = UIViewController.shouldCaptureAutoScreenView("ContentView", from: viewController, at: baseTime.addingTimeInterval(0.25))
                let captureAfterWindow = UIViewController.shouldCaptureAutoScreenView("ContentView", from: viewController, at: baseTime.addingTimeInterval(5.25))

                expect(firstCapture) == true
                expect(duplicateCapture) == false
                expect(captureAfterWindow) == false
            }

            it("captures again after screen transition to a different screen") {
                let baseTime = Date(timeIntervalSince1970: 2000)
                let firstController = UIViewController()
                let secondController = UIViewController()
                let thirdController = UIViewController()

                let firstCapture = UIViewController.shouldCaptureAutoScreenView("ContentView", from: firstController, at: baseTime)
                let secondCapture = UIViewController.shouldCaptureAutoScreenView("SettingsView", from: secondController, at: baseTime.addingTimeInterval(0.25))
                let thirdCapture = UIViewController.shouldCaptureAutoScreenView("ContentView", from: thirdController, at: baseTime.addingTimeInterval(0.5))

                expect(firstCapture) == true
                expect(secondCapture) == true
                expect(thirdCapture) == true
            }

            it("allows same screen after dedupe reset") {
                let baseTime = Date(timeIntervalSince1970: 3000)
                let viewController = UIViewController()

                let firstCapture = UIViewController.shouldCaptureAutoScreenView("ContentView", from: viewController, at: baseTime)
                let duplicateCapture = UIViewController.shouldCaptureAutoScreenView("ContentView", from: viewController, at: baseTime.addingTimeInterval(0.2))

                UIViewController.resetAutoScreenCaptureDedupeState()

                let captureAfterReset = UIViewController.shouldCaptureAutoScreenView("ContentView", from: viewController, at: baseTime.addingTimeInterval(0.3))

                expect(firstCapture) == true
                expect(duplicateCapture) == false
                expect(captureAfterReset) == true
            }

            #if canImport(SwiftUI)
                it("prefers current controller when it is a SwiftUI hosting controller") {
                    let current = UIHostingController(rootView: Text("Current"))
                    let top = UIHostingController(rootView: Text("Top"))

                    let candidate = UIViewController.screenCaptureCandidate(current: current, top: top)

                    expect(candidate) === current
                }
            #endif

            it("uses top controller when current equals top for UIKit flow") {
                let current = UIViewController()

                let candidate = UIViewController.screenCaptureCandidate(current: current, top: current)

                expect(candidate) === current
            }

            it("ignores non-top non-hosting UIKit controllers") {
                let current = UIViewController()
                let top = UIViewController()

                let candidate = UIViewController.screenCaptureCandidate(current: current, top: top)

                expect(candidate).to(beNil())
            }
        }
    }
#endif
