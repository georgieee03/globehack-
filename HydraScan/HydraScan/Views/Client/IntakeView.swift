import SwiftUI

struct IntakeView: View {
    @StateObject private var viewModel: IntakeViewModel
    let onComplete: (ClientProfile) -> Void

    init(user: HydraUser, service: SupabaseServiceProtocol, onComplete: @escaping (ClientProfile) -> Void) {
        _viewModel = StateObject(wrappedValue: IntakeViewModel(user: user, service: service))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepProgressIndicator(
                title: "Intake",
                currentStep: viewModel.currentStep.rawValue + 1,
                totalSteps: IntakeStep.allCases.count
            )

            HydraSectionHeader(
                eyebrow: "Guided Intake",
                title: viewModel.currentStep.title,
                subtitle: viewModel.progressTitle
            )

            Group {
                switch viewModel.currentStep {
                case .bodyMap:
                    BodyMapView(viewModel: viewModel)
                case .signals:
                    SignalEntryView(viewModel: viewModel)
                case .goal:
                    GoalPickerView(viewModel: viewModel)
                case .activity:
                    ActivityContextView(viewModel: viewModel)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            if let errorMessage = viewModel.errorMessage {
                HydraStatusBanner(message: errorMessage, tone: .error, icon: "exclamationmark.triangle.fill")
            }

            HStack {
                if viewModel.currentStep != .bodyMap {
                    Button("Back") {
                        viewModel.goBack()
                    }
                    .buttonStyle(HydraButtonStyle(kind: .secondary))
                }

                Spacer()

                Button(viewModel.currentStep == .activity ? "Start Capture" : "Continue") {
                    if viewModel.currentStep == .activity {
                        Task {
                            if let profile = await viewModel.completeIntake() {
                                onComplete(profile)
                            }
                        }
                    } else {
                        viewModel.advance()
                    }
                }
                .buttonStyle(HydraButtonStyle(kind: .primary))
                .disabled(!viewModel.canContinue || viewModel.isSaving)
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    IntakeView(user: .preview, service: MockSupabaseService.shared) { _ in }
        .padding()
}
