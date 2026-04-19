import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HydraPageHeader(
                        eyebrow: "Client Access",
                        title: "Recovery intelligence, ready when you are.",
                        subtitle: "Sign in to continue your intake, live movement scan, and clinic-connected recovery timeline."
                    )

                    HydraCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Continue with Apple")
                                .font(HydraTypography.section(24))
                                .foregroundStyle(HydraTheme.Colors.primaryText)

                            Text("Use the identity your clinic expects, then pick up where your last capture ended.")
                                .font(HydraTypography.body(15))
                                .foregroundStyle(HydraTheme.Colors.secondaryText)

                            SignInWithAppleButton(.continue) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                handleAppleSignIn(result)
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: HydraTheme.Radius.button, style: .continuous))
                        }
                    }

                    HydraCard(role: .panel) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Magic Link")
                                .font(HydraTypography.section(24))
                                .foregroundStyle(HydraTheme.Colors.primaryText)

                            Text("Prefer email access? We’ll send a secure link to this device.")
                                .font(HydraTypography.body(15))
                                .foregroundStyle(HydraTheme.Colors.secondaryText)

                            HydraInputShell {
                                TextField("you@example.com", text: $viewModel.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(HydraTypography.body(16))
                                    .foregroundStyle(HydraTheme.Colors.primaryText)
                            }

                            Button("Send Magic Link") {
                                Task {
                                    await viewModel.sendMagicLink()
                                }
                            }
                            .buttonStyle(HydraButtonStyle(kind: .secondary))
                        }
                    }

                    HydraCard(role: .ivory) {
                        VStack(alignment: .leading, spacing: 10) {
                            HydraEyebrow(text: "HydraScan System", icon: "waveform.path.ecg")
                            Text("Every recovery session, check-in, and QuickPose capture stays tied to your clinic workflow.")
                                .font(HydraTypography.section(26))
                                .foregroundStyle(HydraTheme.Colors.ink)

                            Text("The app opens into your private recovery timeline as soon as authentication completes.")
                                .font(HydraTypography.body(15))
                                .foregroundStyle(HydraTheme.Colors.inkSecondary)
                        }
                    }

                    if let infoMessage = viewModel.infoMessage {
                        HydraStatusBanner(message: infoMessage, tone: .success, icon: "checkmark.circle.fill")
                    }

                    if let errorMessage = viewModel.errorMessage {
                        HydraStatusBanner(message: errorMessage, tone: .error, icon: "exclamationmark.triangle.fill")
                    }
                }
                .padding(HydraTheme.Spacing.page)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .hydraShell()
            .overlay {
                if viewModel.isLoading {
                    HydraCard {
                        HStack(spacing: 14) {
                            ProgressView()
                                .tint(HydraTheme.Colors.gold)
                            Text("Securing your HydraScan access…")
                                .font(HydraTypography.body(15, weight: .medium))
                                .foregroundStyle(HydraTheme.Colors.primaryText)
                        }
                    }
                    .padding(HydraTheme.Spacing.page)
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

#Preview {
    LoginView(viewModel: AuthViewModel())
}
