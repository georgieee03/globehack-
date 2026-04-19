import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("HydraScan")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Sign in to complete your intake, capture movement, and keep your recovery loop connected to your clinic.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

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

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .failure(error):
            viewModel.errorMessage = error.localizedDescription
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                viewModel.errorMessage = "Apple Sign-In returned an unexpected credential."
                return
            }

            guard
                let identityTokenData = credential.identityToken,
                let identityToken = String(data: identityTokenData, encoding: .utf8)
            else {
                viewModel.errorMessage = AuthServiceError.missingIdentityToken.localizedDescription
                return
            }

            Task {
                await viewModel.signInWithApple(
                    idToken: identityToken,
                    fullName: credential.fullName?.formatted()
                )
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
