import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AuthView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var userIsLoggedIn: Bool = false
    @State private var authListener: AuthStateDidChangeListenerHandle?

    var body: some View {
        VStack {
            if userIsLoggedIn {
                RootTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            setupAuthListener()
            Task {
                await store.load()
            }
        }
        .onDisappear {
            removeAuthListener()
        }
        .tint(Color("ThemeGreen"))
    }
    
    private func setupAuthListener() {
        removeAuthListener()
        
        authListener = Auth.auth().addStateDidChangeListener { _, user in
            guard let user = user else {
                self.store.appMode = .consumer
                self.userIsLoggedIn = false
                return
            }
            
            let db = Firestore.firestore()
            let userDocRef = db.collection("users").document(user.uid)
            
            userDocRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    let data = document.data()
                    let role = data?["role"] as? String ?? "consumer"
                    
                    if role == "merchant" {
                        self.store.appMode = .merchant
                    } else {
                        self.store.appMode = .consumer
                    }
                } else {
                    self.store.appMode = .consumer
                }
                self.userIsLoggedIn = true
            }
        }
    }
    
    private func removeAuthListener() {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
            authListener = nil
        }
    }
}
