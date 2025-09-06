import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ReceiptStore
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var signupSuccessMessage: String?

    private var isSignUpDisabled: Bool {
        email.isEmpty || password.isEmpty || password != confirmPassword
    }

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
            
            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                Text("Passwords do not match.")
                    .font(.caption)
                    .foregroundColor(.red)
            }

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
            .disabled(isSignUpDisabled)

            Button(action: { signUp(role: "merchant") }) {
                Text("Create Merchant Account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(isSignUpDisabled)
            
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
                return
            }
            
            guard let user = authResult?.user else {
                self.errorMessage = "Failed to create user."
                return
            }
            
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).setData(["role": role]) { err in
                if let err = err {
                    self.errorMessage = "Error saving user role: \(err.localizedDescription)"
                } else {
                    if role == "merchant" {
                        store.appMode = .merchant
                    } else {
                        store.appMode = .consumer
                    }
                    self.signupSuccessMessage = "Account created! You are now logged in."
                }
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
