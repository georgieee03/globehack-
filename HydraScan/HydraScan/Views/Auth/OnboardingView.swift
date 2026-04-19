import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HydraPageHeader(
                        eyebrow: "Clinic Connection",
                        title: "Bring HydraScan into your care loop.",
                        subtitle: "Finish your client setup so the app can load your clinic-linked intake, guided motion scan, and recovery history."
                    )

                    HydraCard {
                        VStack(alignment: .leading, spacing: 16) {
                            if let email = viewModel.authUser?.email {
                                HydraEyebrow(text: email, icon: "envelope")
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Name")
                                    .font(HydraTypography.ui(15, weight: .semibold))
                                    .foregroundStyle(HydraTheme.Colors.primaryText)

                                HydraInputShell {
                                    TextField("Jordan Rivera", text: $viewModel.onboardingFullName)
                                        .textContentType(.name)
                                        .font(HydraTypography.body(16))
                                        .foregroundStyle(HydraTheme.Colors.primaryText)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Clinic Invite Code")
                                    .font(HydraTypography.ui(15, weight: .semibold))
                                    .foregroundStyle(HydraTheme.Colors.primaryText)

                                HydraInputShell {
                                    TextField("ABC123", text: $viewModel.clinicInviteCode)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(HydraTypography.body(16))
                                        .foregroundStyle(HydraTheme.Colors.primaryText)
                                }
                            }
                        }
                    }

                    HydraCard(role: .ivory) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("What unlocks after setup")
                                .font(HydraTypography.section(28))
                                .foregroundStyle(HydraTheme.Colors.ink)

                            onboardingFeature(
                                icon: "figure.arms.open",
                                text: "Targeted body-region intake aligned to how you feel today."
                            )
                            onboardingFeature(
                                icon: "camera.viewfinder",
                                text: "Guided QuickPose capture with clinic-aware session continuity."
                            )
                            onboardingFeature(
                                icon: "waveform.path.ecg",
                                text: "Recovery Score updates driven by check-ins, outcomes, and movement data."
                            )
                        }
                    }

                    if let infoMessage = viewModel.infoMessage {
                        HydraStatusBanner(message: infoMessage, tone: .success, icon: "checkmark.circle.fill")
                    }

                    if let errorMessage = viewModel.errorMessage {
                        HydraStatusBanner(message: errorMessage, tone: .error, icon: "exclamationmark.triangle.fill")
                    }

                    Button("Join My Clinic") {
                        Task {
                            await viewModel.completeOnboarding()
                        }
                    }
                    .buttonStyle(HydraButtonStyle(kind: .primary))
                    .disabled(viewModel.isLoading)
                }
                .padding(HydraTheme.Spacing.page)
            }
            .toolbar(.hidden, for: .navigationBar)
            .hydraShell()
            .overlay {
                if viewModel.isLoading {
                    HydraCard {
                        HStack(spacing: 14) {
                            ProgressView()
                                .tint(HydraTheme.Colors.gold)
                            Text("Linking your clinic access…")
                                .font(HydraTypography.body(15, weight: .medium))
                                .foregroundStyle(HydraTheme.Colors.primaryText)
                        }
                    }
                    .padding(HydraTheme.Spacing.page)
                }
            }
        }
    }

    private func onboardingFeature(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(HydraTypography.ui(16, weight: .semibold))
                .foregroundStyle(HydraTheme.Colors.goldDeep)
                .frame(width: 28)

            Text(text)
                .font(HydraTypography.body(15))
                .foregroundStyle(HydraTheme.Colors.inkSecondary)
        }
    }
}

#Preview {
    OnboardingView(viewModel: AuthViewModel())
}
