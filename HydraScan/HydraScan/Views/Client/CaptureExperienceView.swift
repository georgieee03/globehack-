import SwiftUI

private enum CaptureScreen {
    case intake
    case capture(ClientProfile)
    case results(Assessment, AssessmentPersistenceState?)
    case feedback(Assessment)
    case complete
}

struct CaptureExperienceView: View {
    let user: HydraUser
    let service: SupabaseServiceProtocol
    let onFlowFinished: () -> Void

    @State private var screen: CaptureScreen = .intake

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HydraBrandLogo(height: 28)

                    switch screen {
                    case .intake:
                        IntakeView(user: user, service: service) { profile in
                            screen = .capture(profile)
                        }
                    case let .capture(profile):
                        QuickPoseCaptureView(user: user, profile: profile, assessmentType: .intake, service: service) { assessment, persistenceState in
                            screen = .results(assessment, persistenceState)
                        }
                    case let .results(assessment, persistenceState):
                        ResultsSummaryView(
                            user: user,
                            service: service,
                            assessment: assessment,
                            persistenceState: persistenceState,
                            onContinue: { screen = .feedback(assessment) },
                            onStartOver: { screen = .intake }
                        )
                    case let .feedback(assessment):
                        PostSessionView(user: user, assessment: assessment, service: service) {
                            screen = .complete
                        }
                    case .complete:
                        completionView
                    }
                }
                .padding(HydraTheme.Spacing.page)
            }
            .toolbar(.hidden, for: .navigationBar)
            .hydraShell()
        }
    }

    private var completionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HydraBrandStage(
                eyebrow: "7-Step Onboarding Scan",
                title: "Your onboarding motion baseline is saved.",
                subtitle: "All seven guided poses, your live capture, and post-session feedback are now part of your recovery timeline."
            )

            HydraCard(role: .ivory) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What happens next")
                        .font(HydraTypography.section(28))
                        .foregroundStyle(HydraTheme.Colors.ink)
                    Text("Return home to review your updated recovery view or begin a new capture when you’re ready.")
                        .font(HydraTypography.body(15))
                        .foregroundStyle(HydraTheme.Colors.inkSecondary)
                }
            }

            HStack {
                Button("Start Another Session") {
                    screen = .intake
                }
                .buttonStyle(HydraButtonStyle(kind: .secondary))

                Spacer()

                Button("Return to Overview") {
                    onFlowFinished()
                }
                .buttonStyle(HydraButtonStyle(kind: .primary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }
}

#Preview {
    CaptureExperienceView(user: .preview, service: MockSupabaseService.shared) {}
}
