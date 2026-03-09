import SwiftUI

struct LoginView: View {
    @ObservedObject var authManager = FakeAuthManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    // Using an injected closure from ContentView or routing it directly
    // since SwiftUI iOS14+ navigation flow might vary, we can just pop and let publisher continue,
    // or trigger a specific navigation state.
    var onLoginSuccess: ((String?) -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login Required")
                .font(.largeTitle)
                .bold()
            
            Text("Please login to access this profile screen.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                authManager.login()
                let destination = authManager.consumePendingDeepLink()
                print("🔗 Login Successful. Resuming pending deep link destination: \(destination ?? "none")")
                onLoginSuccess?(destination)
            }) {
                Text("Login")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Login")
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
