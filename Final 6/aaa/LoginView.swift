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
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 50)
                    
                    Text("OURECEIPT")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(Color("ThemeGreen"))

                    Spacer(minLength: 30)
                    
                    VStack(spacing: 15) {
                        TextField("Email", text: $email)
                            .font(.body)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)

                        SecureField("Password", text: $password)
                            .font(.body)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .textContentType(.password)
                        
                        Toggle("Remember Email", isOn: $rememberEmail)
                            .font(.subheadline)
                            .padding(.horizontal, 4)
                    }

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: login) {
                        Text("Login")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Color("ThemeGreen"))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Divider()
                        .padding(.vertical, 10)

                    NavigationLink("Don't have an account? Sign Up") {
                        SignUpSelectionView()
                            .environmentObject(store)
                    }
                    .font(.subheadline)
                    .tint(Color("ThemeGreen"))
                }
                .padding(30)
            }
            .navigationTitle("Welcome")
            .navigationBarHidden(true)
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
