import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    
    @State private var rememberEmail: Bool = false
    @AppStorage("savedEmail") private var savedEmail: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.gray)
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Toggle("Remember Email", isOn: $rememberEmail)
                    .padding(.horizontal, 1)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: login) {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                }
                .tint(.blue)
                .buttonStyle(.borderedProminent)
                
                Divider()

                NavigationLink("Don't have an account? Sign Up") {
                    SignUpView()
                        .environmentObject(store)
                }
            }
            .padding()
            .navigationTitle("Welcome")
            .onAppear {
                if !savedEmail.isEmpty {
                    self.email = savedEmail
                    self.rememberEmail = true
                }
            }
        }
    }

    func login() {
        if rememberEmail {
            savedEmail = email
        } else {
            savedEmail = ""
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = nil
                password = ""
            }
        }
    }
}
