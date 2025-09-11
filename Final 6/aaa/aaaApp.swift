import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct aaaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = ReceiptStore()
    
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding: Bool = true

    var body: some Scene {
        WindowGroup {
            AuthView()
                .environmentObject(store)
                .sheet(isPresented: $shouldShowOnboarding) {
                    OnboardingView(shouldShowOnboarding: $shouldShowOnboarding)
                }
        }
    }
}
