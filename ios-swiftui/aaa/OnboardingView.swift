import SwiftUI

struct OnboardingView: View {
    @Binding var shouldShowOnboarding: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "tree.circle.fill")
                .font(.system(size: 120))
                .foregroundColor(Color("ThemeGreen"))
            
            Text("Welcome to OURECEIPT")
                .font(.largeTitle.weight(.bold))
            
            Text("Saving one paper receipt at a time\nhelps protect our trees, water, and future.\n\nJoin us in building a greener Singapore!")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                shouldShowOnboarding = false
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("ThemeGreen"))
                    .cornerRadius(12)
            }
        }
        .padding(30)
    }
}

#Preview {
    OnboardingView(shouldShowOnboarding: .constant(true))
}
