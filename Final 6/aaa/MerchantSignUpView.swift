import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PhotosUI

struct MerchantSignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ReceiptStore
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    @State private var merchantName: String = ""
    @State private var location: String = ""
    @State private var address: String = ""
    @State private var phoneNumber: String = ""
    @State private var selectedCurrency: Currency = .sgd
    @State private var selectedGreenTags: Set<GreenTag> = []
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var logoImageData: Data?

    @State private var errorMessage: String?
    @State private var signupSuccessMessage: String?
    @State private var isSigningUp = false

    private var isSignUpDisabled: Bool {
        if email.isEmpty { return true }
        if password.isEmpty { return true }
        if password.count < 6 { return true }
        if password != confirmPassword { return true }
        if merchantName.isEmpty { return true }
        if isSigningUp { return true }
        
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Join as Merchant")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color.orange)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("ACCOUNT CREDENTIALS")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("Email Address", text: $email)
                        .styled()
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                    
                    SecureField("Password (min 6 characters)", text: $password)
                        .styled()
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .styled()
                        .textContentType(.newPassword)
                    
                    if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords do not match.").font(.caption).foregroundColor(.red)
                    }
                    if password.count < 6 && !password.isEmpty {
                        Text("Password must be at least 6 characters.").font(.caption).foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("STORE INFORMATION")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("Store Name (Required)", text: $merchantName).styled()
                    TextField("Postal Code (Optional)", text: $address).styled()
                    TextField("Address (e.g., 123 Orchard Road)", text: $location).styled()
                    TextField("Phone Number (Optional)", text: $phoneNumber)
                        .styled()
                        .keyboardType(.phonePad)
                    
                    HStack {
                        Text("Default Currency")
                            .font(.body)
                        Spacer()
                        Picker("Default Currency", selection: $selectedCurrency) {
                            ForEach(Currency.allCases) { currency in
                                Text(currency.rawValue).tag(currency)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.orange)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("STORE LOGO")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        HStack {
                            Image(systemName: "photo.fill")
                            Text("Select Store Logo")
                            Spacer()
                        }
                        .font(.headline)
                        .foregroundColor(.orange)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    
                    if let logoData = logoImageData, let uiImage = UIImage(data: logoData) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("ECO-FRIENDLY FEATURES")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    ForEach(GreenTag.allCases) { tag in
                        let isSelected = selectedGreenTags.contains(tag)
                        HStack {
                            Image(systemName: tag.icon)
                            Text(tag.rawValue)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .foregroundColor(isSelected ? .white : .primary)
                        .background(isSelected ? Color.orange : Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .onTapGesture {
                            if isSelected {
                                selectedGreenTags.remove(tag)
                            } else {
                                selectedGreenTags.insert(tag)
                            }
                        }
                    }
                }

                VStack(spacing: 15) {
                    if let errorMessage = errorMessage {
                        Text(errorMessage).foregroundColor(.red).font(.subheadline)
                    }
                    if let successMessage = signupSuccessMessage {
                        Text(successMessage).foregroundColor(.green).font(.subheadline)
                    }
                    
                    Button(action: {
                        Task {
                            await signUp()
                        }
                    }) {
                        if isSigningUp {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Merchant Account")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                    .disabled(isSignUpDisabled)
                }
                .padding(.top, 20)
            }
            .padding(30)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    logoImageData = data
                }
            }
        }
    }

    func signUp() async {
        isSigningUp = true
        self.errorMessage = nil
        self.signupSuccessMessage = nil

        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let user = authResult.user
            let db = Firestore.firestore()

            let newProfile = MerchantProfile(
                id: user.uid,
                merchantName: merchantName,
                location: location.isEmpty ? nil : location,
                address: address.isEmpty ? nil : address,
                phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                logoImageData: logoImageData,
                defaultCurrency: selectedCurrency,
                greenTags: Array(selectedGreenTags),
                hasGreenTags: !selectedGreenTags.isEmpty
            )
            
            try await db.collection("users").document(user.uid).setData(["role": "merchant", "email": email])
            try db.collection("merchant_profiles").document(user.uid).setData(from: newProfile)
            
            await MainActor.run {
                self.store.merchantProfile = newProfile
                self.store.appMode = .merchant
                self.signupSuccessMessage = "Account created successfully! You are now logged in."
                self.isSigningUp = false
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isSigningUp = false
            }
        }
    }
}

struct StyledTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
    }
}

extension View {
    func styled() -> some View {
        self.modifier(StyledTextField())
    }
}
