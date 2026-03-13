import SwiftUI

struct ProfileView: View {
    @ObservedObject var authManager = FakeAuthManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("User Profile")
                .font(.largeTitle)
                .bold()
            
            Text("Welcome to the secure Profile area.")
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
            
            Button(action: {
                authManager.logout()
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Logout")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .navigationTitle("Profile")
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
