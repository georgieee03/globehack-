import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to HydraScan")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("This app helps you capture recovery signals, move through a guided assessment, and share structured wellness insights with your practitioner.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                Label("Tap body regions that need support", systemImage: "figure.arms.open")
                Label("Move through a fast seven-step capture flow", systemImage: "camera.viewfinder")
                Label("Keep momentum with daily check-ins and streaks", systemImage: "bolt.heart")
            }
            .font(.headline)

            Button("Start My Recovery Flow") {
                viewModel.finishOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(24)
    }
}

#Preview {
    OnboardingView(viewModel: AuthViewModel())
}
