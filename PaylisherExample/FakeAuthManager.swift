import Foundation
import Combine

class FakeAuthManager: ObservableObject {
    static let shared = FakeAuthManager()
    
    @Published var isAuthenticated: Bool = false
    private var pendingDeepLinkDestination: String? = nil
    
    private init() {
        // Simple initialization
    }
    
    func login() {
        isAuthenticated = true
    }
    
    func logout() {
        isAuthenticated = false
        pendingDeepLinkDestination = nil
    }
    
    func setPendingDeepLink(destination: String) {
        pendingDeepLinkDestination = destination
    }
    
    func consumePendingDeepLink() -> String? {
        let dest = pendingDeepLinkDestination
        pendingDeepLinkDestination = nil
        return dest
    }
}
