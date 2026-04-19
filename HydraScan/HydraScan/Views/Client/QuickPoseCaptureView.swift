import SwiftUI

struct QuickPoseCaptureView: View {
    @StateObject private var viewModel: CaptureViewModel
    let onComplete: (Assessment, AssessmentPersistenceState?) -> Void

    init(
        user: HydraUser,
        profile: ClientProfile,
        service: SupabaseServiceProtocol,
        onComplete: @escaping (Assessment, AssessmentPersistenceState?) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: CaptureViewModel(user: user, profile: profile, service: service))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepProgressIndicator(
                title: "Guided Capture",
                currentStep: viewModel.flowState == .results ? HydraScanConstants.captureSteps.count : viewModel.currentStepIndex + 1,
                totalSteps: HydraScanConstants.captureSteps.count
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.currentStep.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(viewModel.currentStep.instruction)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.teal.opacity(0.85), .cyan.opacity(0.65), .mint.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 20) {
                    Image(systemName: "figure.mind.and.body")
                        .font(.system(size: 74))
                        .foregroundStyle(.white.opacity(0.88))

                    Text(viewModel.flowState == .capturing ? "\(viewModel.remainingSeconds)s" : "Ready")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if viewModel.currentStep.step == .squat || viewModel.currentStep.step == .hipHinge {
                        Text("Rep Count: \(viewModel.repCount)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    } else {
                        Text("On-device QuickPose overlay will land here next.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding()
            }
            .frame(height: 360)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }

            HStack {
                Button(viewModel.flowState == .capturing ? "Restart" : "Start Capture") {
                    viewModel.startCapture()
                }
                .buttonStyle(.borderedProminent)

                Button("Skip Demo Timing") {
                    viewModel.skipToResults()
                }
                .buttonStyle(.bordered)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Saving assessment...")
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
            }
        }
        .onChange(of: viewModel.latestAssessment) { _, newValue in
            if let newValue {
                onComplete(newValue, viewModel.persistenceState)
            }
        }
    }
}

#Preview {
    QuickPoseCaptureView(
        user: .preview,
        profile: .preview,
        service: MockSupabaseService.shared
    ) { _, _ in }
    .padding()
}
