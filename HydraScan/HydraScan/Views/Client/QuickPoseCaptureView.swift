import AVFoundation
import SwiftUI

#if canImport(QuickPoseCore) && canImport(QuickPoseSwiftUI)
import QuickPoseCore
import QuickPoseSwiftUI
#endif

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
                currentStep: viewModel.flowState == .results ? viewModel.captureSteps.count : viewModel.currentStepIndex + 1,
                totalSteps: viewModel.captureSteps.count
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.currentStep.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(viewModel.currentStep.instruction)
                    .foregroundStyle(.secondary)
            }

            previewCard

            VStack(alignment: .leading, spacing: 12) {
                statRow(label: "Status", value: viewModel.liveStatusText)
                statRow(label: "Frames Captured", value: "\(viewModel.capturedFrameCount)")
                statRow(label: "Estimated Reps", value: "\(viewModel.repCount)")

                if viewModel.currentMetrics.isEmpty {
                    Text("Live ROM and asymmetry metrics will appear here as QuickPose tracks you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.currentMetrics) { metric in
                        statRow(label: metric.name, value: metric.stringValue)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )

            Text(viewModel.supportNote)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !viewModel.hasConfiguredSDKKey {
                Text("QuickPose SDK key is missing from this build.")
                    .foregroundStyle(.orange)
                    .font(.subheadline.weight(.semibold))
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }

            HStack {
                Button(viewModel.flowState == .capturing ? "Restart Capture" : "Start Capture") {
                    viewModel.startCapture()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.supportsQuickPoseRuntime || !viewModel.hasConfiguredSDKKey)

                Button(viewModel.flowState == .capturing ? "Finish Early" : "Reset") {
                    if viewModel.flowState == .capturing {
                        viewModel.skipToResults()
                    } else {
                        viewModel.reset()
                    }
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
        .onAppear {
            viewModel.startQuickPosePreview()
        }
        .onDisappear {
            viewModel.stopQuickPosePreview()
        }
        .onChange(of: viewModel.latestAssessment) { _, newValue in
            if let newValue {
                onComplete(newValue, viewModel.persistenceState)
            }
        }
    }

    private var previewCard: some View {
        ZStack(alignment: .topLeading) {
            previewContent

            LinearGradient(
                colors: [.black.opacity(0.7), .black.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.flowState == .capturing ? "\(viewModel.remainingSeconds)s" : "Live")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(viewModel.flowState == .capturing ? "Recording \(viewModel.currentStep.title.lowercased())" : "QuickPose preview")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))

                if viewModel.repCount > 0 {
                    Text("Rep Count: \(viewModel.repCount)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var previewContent: some View {
        #if canImport(QuickPoseCore) && canImport(QuickPoseSwiftUI)
        if viewModel.usesLiveCamera {
            ZStack {
                QuickPoseCameraView(
                    useFrontCamera: true,
                    delegate: viewModel.quickPoseDelegate,
                    videoGravity: .resizeAspectFill
                )
                QuickPoseOverlayView(overlayImage: $viewModel.overlayImage, contentMode: .fit)
            }
        } else if viewModel.usesBundledClipPreview, let clipURL = viewModel.previewClipURL {
            ZStack {
                QuickPoseSimulatedCameraView(
                    useFrontCamera: true,
                    delegate: viewModel.quickPoseDelegate,
                    video: clipURL,
                    videoGravity: .resizeAspectFill
                )
                QuickPoseOverlayView(overlayImage: $viewModel.overlayImage, contentMode: .fit)
            }
        } else {
            unsupportedPreview
        }
        #else
        unsupportedPreview
        #endif
    }

    private var unsupportedPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.88))

            Text("QuickPose live capture is unavailable on this runtime.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(viewModel.supportNote)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.84))
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.indigo.opacity(0.8), .teal.opacity(0.72), .mint.opacity(0.52)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func statRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 124, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
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
