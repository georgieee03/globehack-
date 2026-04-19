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
    let service: InsforgeServiceProtocol
    let onFlowFinished: () -> Void

    @State private var screen: CaptureScreen = .intake

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch screen {
                    case .intake:
                        IntakeView(user: user, service: service) { profile in
                            screen = .capture(profile)
                        }
                    case let .capture(profile):
                        QuickPoseCaptureView(user: user, profile: profile, service: service) { assessment, persistenceState in
                            screen = .results(assessment, persistenceState)
                        }
                    case let .results(assessment, persistenceState):
                        ResultsSummaryView(
                            assessment: assessment,
                            persistenceState: persistenceState,
                            onContinue: { screen = .feedback(assessment) },
                            onStartOver: { screen = .intake }
                        )
                    case let .feedback(assessment):
                        PostSessionView(user: user, assessment: assessment, service: service) {
                            screen = .complete
                            onFlowFinished()
                        }
                    case .complete:
                        completionView
                    }
                }
                .padding(24)
            }
            .navigationTitle("Capture")
        }
    }

    private var completionView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Session Logged")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Your intake, movement capture, and post-session feedback are all saved. Head back home to review your updated momentum.")
                .foregroundStyle(.secondary)

            Button("Start Another Session") {
                screen = .intake
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 40)
    }
}

#Preview {
    CaptureExperienceView(user: .preview, service: MockInsforgeService.shared) {}
}
