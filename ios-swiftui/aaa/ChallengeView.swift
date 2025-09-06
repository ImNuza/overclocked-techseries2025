//import SwiftUI
//
//struct ChallengeView: View {
//    @EnvironmentObject var store: ReceiptStore
//
//    private let allChallenges = ChallengeProvider.allChallenges
//
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(alignment: .leading, spacing: 20) {
//                    Text("SGP30 Weekly Challenges")
//                        .font(.largeTitle.weight(.bold))
//                        .padding(.horizontal)
//
//                    ForEach(allChallenges) { challenge in
//                        ChallengeCard(challenge: challenge)
//                    }
//                }
//                .padding(.vertical)
//            }
//            .background(Color(.systemGroupedBackground))
//            .navigationTitle("Challenges")
//            .navigationBarHidden(true)
//        }
//    }
//}
//
//struct ChallengeCard: View {
//    @EnvironmentObject var store: ReceiptStore
//    let challenge: Challenge
//
//    private var progress: ChallengeProgress {
//        store.challengeProgress.first(where: { $0.challengeId == challenge.id }) ??
//        ChallengeProgress(challengeId: challenge.id, currentCount: 0, lastUpdated: Date())
//    }
//
//    private var progressValue: Double {
//        Double(progress.currentCount) / Double(challenge.targetCount)
//    }
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Image(systemName: challenge.iconName)
//                    .font(.title)
//                    .foregroundColor(Color("ThemeGreen"))
//                    .frame(width: 40)
//
//                VStack(alignment: .leading) {
//                    Text(challenge.title)
//                        .font(.headline.weight(.bold))
//                    Text(challenge.description)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                        .lineLimit(2)
//                }
//            }
//
//            ProgressView(value: progressValue) {
//                HStack {
//                    Text("Progress")
//                        .font(.caption)
//                    Spacer()
//                    Text("\(progress.currentCount) / \(challenge.targetCount)")
//                        .font(.caption.weight(.semibold))
//                }
//            }
//            .tint(Color("ThemeGreen"))
//
//            if progress.isCompleted {
//                HStack {
//                    Spacer()
//                    Label("Completed!", systemImage: "checkmark.circle.fill")
//                        .font(.caption.weight(.bold))
//                        .foregroundColor(.white)
//                        .padding(.horizontal, 10)
//                        .padding(.vertical, 5)
//                        .background(Color("ThemeGreen"))
//                        .clipShape(Capsule())
//                }
//                .padding(.top, 5)
//            }
//        }
//        .padding()
//        .background(Color(.secondarySystemBackground))
//        .cornerRadius(16)
//        .padding(.horizontal)
//    }
//}
//
//#Preview {
//    ChallengeView()
//        .environmentObject(ReceiptStore())
//}
