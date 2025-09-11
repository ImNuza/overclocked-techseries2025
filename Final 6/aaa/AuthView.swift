import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AuthView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var userState: UserState = .unknown
    @State private var authListener: AuthStateDidChangeListenerHandle?

    enum UserState {
        case unknown
        case loggedOut
        case loggedInConsumer
        case loggedInMerchant
    }

    var body: some View {
        VStack {
            switch userState {
            case .unknown:
                ProgressView()
            case .loggedOut:
                LoginView()
            case .loggedInConsumer, .loggedInMerchant:
                RootTabView()
            }
        }
        .onAppear {
            setupAuthListener()
        }
        .onDisappear {
            removeAuthListener()
        }
        .tint(Color("ThemeGreen"))
    }
    
    private func setupAuthListener() {
        removeAuthListener()
        
        authListener = Auth.auth().addStateDidChangeListener { _, user in
            Task {
                await checkUserStatus(user: user)
            }
        }
    }
    
    @MainActor
    private func checkUserStatus(user: User?) async {
        guard let user = user else {
            self.store.clearAllUserData()
            self.userState = .loggedOut
            return
        }
        
        let db = Firestore.firestore()
        let userDocRef = db.collection("users").document(user.uid)
        
        do {
            let document = try await userDocRef.getDocument()
            
            if document.exists {
                let data = document.data()
                let role = data?["role"] as? String ?? "consumer"
                
                if role == "merchant" {
                    self.store.appMode = .merchant
                    if store.merchantProfile == nil {
                        await loadAllMerchantData(for: user.uid)
                    }
                    self.userState = .loggedInMerchant
                } else {
                    self.store.appMode = .consumer
                    await store.loadConsumerData(uid: user.uid)
                    self.userState = .loggedInConsumer
                }
            } else {
                self.store.appMode = .consumer
                self.userState = .loggedInConsumer
            }
        } catch {
            print("Error getting user document: \(error)")
            self.store.appMode = .consumer
            self.userState = .loggedInConsumer
        }
    }
    
    @MainActor
    private func loadAllMerchantData(for uid: String) async {
        let db = Firestore.firestore()
        let profileDocRef = db.collection("merchant_profiles").document(uid)
        
        do {
            self.store.merchantProfile = try await profileDocRef.getDocument(as: MerchantProfile.self)
            await store.loadMerchantData(uid: uid)
        } catch {
            print("Error decoding merchant profile or subcollections: \(error)")
            self.store.merchantProfile = nil
        }
    }
    
    private func removeAuthListener() {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
            authListener = nil
        }
    }
}
