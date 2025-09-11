import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PhotosUI

struct CustomerSignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ReceiptStore
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var signupSuccessMessage: String?

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?

    private var isSignUpDisabled: Bool {
        email.isEmpty || password.isEmpty || password != confirmPassword || password.count < 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                Text("Join as Customer")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color("ThemeGreen"))
                
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    VStack {
                        if let imageData = profileImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 4))
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 150))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        Text("Choose Profile Photo")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                            .padding(.top, 5)
                    }
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            profileImageData = data
                        }
                    }
                }
                
                VStack(spacing: 15) {
                    TextField("Email Address", text: $email)
                        .font(.body)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)

                    SecureField("Password (min 6 characters)", text: $password)
                        .font(.body)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .font(.body)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .textContentType(.newPassword)
                }

                if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                    Text("Passwords do not match.")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                if password.count < 6 && !password.isEmpty {
                    Text("Password must be at least 6 characters.")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                
                if let successMessage = signupSuccessMessage {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }

                Button(action: signUp) {
                    Text("Create Customer Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("ThemeGreen"))
                .controlSize(.large)
                .disabled(isSignUpDisabled)
                
                Spacer()
            }
            .padding(30)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    func signUp() {
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
            let userData: [String: Any] = [
                "role": "consumer",
                "email": email,
                "profileImageData": profileImageData?.base64EncodedString() ?? ""
            ]
            
            db.collection("users").document(user.uid).setData(userData) { err in
                if let err = err {
                    self.errorMessage = "Error saving user data: \(err.localizedDescription)"
                } else {
                    store.appMode = .consumer
                    self.signupSuccessMessage = "Account created successfully! You are now logged in."
                }
            }
        }
    }
}
