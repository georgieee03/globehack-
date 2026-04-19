import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("HydraScan")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Sign in to start your intake, capture your movement session, and keep your recovery loop moving.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    Button {
                        Task {
                            await viewModel.signInWithApple()
                        }
                    } label: {
                        Label("Continue with Apple", systemImage: "applelogo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Or use a magic link")
                            .font(.headline)

                        TextField("you@example.com", text: $viewModel.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )

                        Button("Send Magic Link") {
                            Task {
                                await viewModel.sendMagicLink()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let infoMessage = viewModel.infoMessage {
                    StatusBanner(message: infoMessage, tint: .teal)
                }

                if let errorMessage = viewModel.errorMessage {
                    StatusBanner(message: errorMessage, tint: .red)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Sign In")
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Working...")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground))
                        )
                }
            }
        }
    }
}

private struct StatusBanner: View {
    let message: String
    let tint: Color

    var body: some View {
        Text(message)
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
