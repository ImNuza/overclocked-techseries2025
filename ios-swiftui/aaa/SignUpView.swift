import SwiftUI
import FirebaseAuth

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ReceiptStore
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var signupSuccessMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 100))
                .foregroundColor(.gray)
            
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if let successMessage = signupSuccessMessage {
                Text(successMessage)
                    .foregroundColor(.green)
                    .font(.caption)
            }

            Button(action: { signUp(role: "consumer") }) {
                Text("Create Customer Account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.green)

            Button(action: { signUp(role: "merchant") }) {
                Text("Create Merchant Account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    func signUp(role: String) {
        self.errorMessage = nil
        self.signupSuccessMessage = nil

        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            } else {
                if let user = authResult?.user {
                    UserDefaults.standard.set(role, forKey: "\(user.uid)_role")
                    
                    if role == "merchant" {
                        store.appMode = .merchant
                    } else {
                        store.appMode = .consumer
                    }
                }
                self.signupSuccessMessage = "Account created! You are now logged in."
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(ReceiptStore())
    }
}
