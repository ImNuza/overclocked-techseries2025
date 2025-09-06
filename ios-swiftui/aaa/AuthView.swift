import SwiftUI
import FirebaseAuth

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
        // Remove existing listener if any
        removeAuthListener()
        
        // Add new listener and store the handle
        authListener = Auth.auth().addStateDidChangeListener { _, user in
            if let user = user {
                let roleKey = "\(user.uid)_role"
                if let role = UserDefaults.standard.string(forKey: roleKey), role == "merchant" {
                    self.store.appMode = .merchant
                } else {
                    self.store.appMode = .consumer
                }
                self.userIsLoggedIn = true
            } else {
                self.store.appMode = .consumer
                self.userIsLoggedIn = false
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
