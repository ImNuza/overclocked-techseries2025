import SwiftUI

struct SignUpSelectionView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Text("Join OURECEIPT")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundColor(Color("ThemeGreen"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)

                Text("Choose an account type that best suits your needs to start your digital receipt journey.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                NavigationLink(destination: CustomerSignUpView()) {
                    VStack(spacing: 15) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("I'm a Customer")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                        Text("Go paperless, track spending, and discover eco-friendly stores.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(Color("ThemeGreen").gradient)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink(destination: MerchantSignUpView()) {
                    VStack(spacing: 15) {
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("I'm a Merchant")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                        Text("Issue digital receipts, manage products, and gain valuable insights.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            // This was the problem area. Changed to a guaranteed visible color.
                            .fill(Color.orange.gradient)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(20)
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct SignUpSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SignUpSelectionView()
        }
    }
}
