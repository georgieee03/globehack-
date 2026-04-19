import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Complete Your Client Setup")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Finish your clinic connection so HydraScan can load your intake, movement capture, and recovery timeline.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    if let email = viewModel.authUser?.email {
                        Label(email, systemImage: "envelope")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .font(.headline)
                        TextField("Jordan Rivera", text: $viewModel.onboardingFullName)
                            .textContentType(.name)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clinic Invite Code")
                            .font(.headline)
                        TextField("ABC123", text: $viewModel.clinicInviteCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Label("Tap body regions that need support", systemImage: "figure.arms.open")
                    Label("Move through a guided QuickPose recovery capture", systemImage: "camera.viewfinder")
                    Label("Keep your Recovery Score moving with check-ins and outcomes", systemImage: "waveform.path.ecg")
                }
                .font(.headline)

                if let infoMessage = viewModel.infoMessage {
                    Text(infoMessage)
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                Button("Join My Clinic") {
                    Task {
                        await viewModel.completeOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoading)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Welcome")
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Linking your clinic access...")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground))
                        )
                }
            }
        }
    }
}

#Preview {
    OnboardingView(viewModel: AuthViewModel())
}
