//
//  PaylisherDeepLinkManagerTest.swift
//  PaylisherTests
//
//  Created by Yusuf Uluşahin on 14.10.23.
//

import Foundation
import Nimble
import Quick

@testable import Paylisher

class PaylisherDeepLinkManagerTest: QuickSpec {
    
    // Mock Handler
    class MockDeepLinkHandler: NSObject, PaylisherDeepLinkHandler {
        var lastReceivedDeepLink: PaylisherDeepLink?
        var lastRequiresAuth: Bool?
        var onReceive: (() -> Void)?
        
        func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
            lastReceivedDeepLink = deepLink
            lastRequiresAuth = requiresAuth
            onReceive?()
        }
    }
    
    override func spec() {
        
        var sut: PaylisherDeepLinkManager!
        
        beforeEach {
            sut = PaylisherDeepLinkManager.shared
            // Reset state
            sut.handler = nil
            // Reset via private/internal properties if possible, or just re-initialize
            // Since it's a singleton, we need to be careful.
            // But we can just set handler to nil and pending to nil effectively via 'clearPendingDeepLink'
            // and relying on our new logic.
            
            // NOTE: 'pendingHandlerDeepLink' is internal/public read-only in our change?
            // Let's rely on public API to reset if needed or just use handleURL
            
            // To properly reset, we might need to expose a reset method or use internal access if @testable is working well.
            // For now, re-instantiating the singleton isn't possible (it's static let).
            // So we manually reset its state:
            sut.handler = nil
            // We can't easily clear 'pendingHandlerDeepLink' because it's private(set).
            // However, initializing with a handler will clear it.
            // So let's dummy clear it by initializing with a dummy handler, then setting handler to nil.
            
            let dummy = MockDeepLinkHandler()
            sut.handler = dummy
            sut.initialize() // clears pending
            sut.handler = nil // now we are in "no handler" state
        }
        
        it("stores deep link as pending when no handler is set") {
            // Given: No handler is set (done in beforeEach)
            
            // When: A deep link is handled
            let url = URL(string: "paylisher://test_destination?param=1")!
            let processed = sut.handleURL(url)
            
            // Then: It returns true (handled/stored)
            expect(processed).to(beTrue())
            
            // And: It is stored in pendingHandlerDeepLink
            expect(sut.pendingHandlerDeepLink).toNot(beNil())
            expect(sut.pendingHandlerDeepLink?.destination).to(equal("test_destination"))
            
            // And: Since no handler, no callback could have happened (implicit)
        }
        
        it("delivers pending deep link immediately when handler is set") {
            // Given: A pending deep link exists (from previous test logic)
            let url = URL(string: "paylisher://pending_test")!
            _ = sut.handleURL(url)
            expect(sut.pendingHandlerDeepLink).toNot(beNil())
            
            // When: A handler is set and initialized
            let mockHandler = MockDeepLinkHandler()
            sut.handler = mockHandler
            sut.initialize()
            
            // Then: The handler receives the deep link
            expect(mockHandler.lastReceivedDeepLink).toNot(beNil())
            expect(mockHandler.lastReceivedDeepLink?.destination).to(equal("pending_test"))
            
            // And: The pending property is cleared
            expect(sut.pendingHandlerDeepLink).to(beNil())
        }
        
        it("handles deep link immediately if handler is already set") {
            // Given: Handler is set
            let mockHandler = MockDeepLinkHandler()
            sut.handler = mockHandler
            sut.initialize()
            
            // When: A deep link comes
            let url = URL(string: "paylisher://immediate_test")!
            _ = sut.handleURL(url)
            
            // Then: Processed immediately
            expect(mockHandler.lastReceivedDeepLink?.destination).to(equal("immediate_test"))
            
            // And: Not stored as pending
            expect(sut.pendingHandlerDeepLink).to(beNil())
        }
    }
}
