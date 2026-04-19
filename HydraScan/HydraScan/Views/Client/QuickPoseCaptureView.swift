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

            HydraSectionHeader(
                eyebrow: "Hydra Motion Scan",
                title: viewModel.currentStep.title,
                subtitle: viewModel.currentStep.instruction
            )

            previewCard

            HydraCard(role: .panel) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Live Telemetry")
                        .font(HydraTypography.section(26))
                        .foregroundStyle(HydraTheme.Colors.primaryText)

                    HydraMetricRow(label: "Status", value: viewModel.liveStatusText)
                    HydraMetricRow(label: "Frames Captured", value: "\(viewModel.capturedFrameCount)")
                    HydraMetricRow(label: "Estimated Reps", value: "\(viewModel.repCount)")

                    if viewModel.currentMetrics.isEmpty {
                        Text("Live ROM and asymmetry metrics appear here as QuickPose tracks your movement in frame.")
                            .font(HydraTypography.body(15))
                            .foregroundStyle(HydraTheme.Colors.secondaryText)
                    } else {
                        ForEach(viewModel.currentMetrics) { metric in
                            HydraMetricRow(label: metric.name, value: metric.stringValue)
                        }
                    }
                }
            }

            Text(viewModel.supportNote)
                .font(HydraTypography.body(13, weight: .medium))
                .foregroundStyle(HydraTheme.Colors.secondaryText)

            if !viewModel.hasConfiguredSDKKey {
                HydraStatusBanner(message: "QuickPose SDK key is missing from this build.", tone: .warning, icon: "key.fill")
            }

            if let errorMessage = viewModel.errorMessage {
                HydraStatusBanner(message: errorMessage, tone: .error, icon: "exclamationmark.triangle.fill")
            }

            HStack {
                Button(viewModel.flowState == .capturing ? "Restart Capture" : "Start Capture") {
                    viewModel.startCapture()
                }
                .buttonStyle(HydraButtonStyle(kind: .primary))
                .disabled(!viewModel.supportsQuickPoseRuntime || !viewModel.hasConfiguredSDKKey)

                Button(viewModel.flowState == .capturing ? "Finish Early" : "Reset") {
                    if viewModel.flowState == .capturing {
                        viewModel.skipToResults()
                    } else {
                        viewModel.reset()
                    }
                }
                .buttonStyle(HydraButtonStyle(kind: .secondary))
            }
        }
        .overlay {
            if viewModel.isLoading {
                HydraCard {
                    HStack(spacing: 14) {
                        ProgressView()
                            .tint(HydraTheme.Colors.gold)
                        Text("Saving your latest movement session…")
                            .font(HydraTypography.body(15, weight: .medium))
                            .foregroundStyle(HydraTheme.Colors.primaryText)
                    }
                }
                .padding(HydraTheme.Spacing.page)
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
                colors: [HydraTheme.Colors.overlay, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.flowState == .capturing ? "\(viewModel.remainingSeconds)s" : "Live")
                    .font(HydraTypography.numeric(42))
                    .foregroundStyle(HydraTheme.Colors.primaryText)

                Text(viewModel.flowState == .capturing ? "Recording \(viewModel.currentStep.title.lowercased())" : "QuickPose preview")
                    .font(HydraTypography.ui(15, weight: .semibold))
                    .foregroundStyle(HydraTheme.Colors.primaryText.opacity(0.92))

                if viewModel.repCount > 0 {
                    HydraTelemetryBadge(label: "Rep Count", value: "\(viewModel.repCount)")
                }
            }
            .padding(20)

            VStack {
                Spacer()

                HStack {
                    HydraTelemetryBadge(label: "Frames", value: "\(viewModel.capturedFrameCount)")
                    Spacer()
                    HydraBrandEmblem(size: 34)
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .background(HydraTheme.Colors.shell)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HydraTheme.Radius.media, style: .continuous)
                .stroke(HydraTheme.Colors.stroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 28, x: 0, y: 16)
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
                .foregroundStyle(HydraTheme.Colors.primaryText.opacity(0.88))

            Text("QuickPose live capture is unavailable on this runtime.")
                .font(HydraTypography.section(28))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            Text(viewModel.supportNote)
                .font(HydraTypography.body(15))
                .foregroundStyle(HydraTheme.Colors.secondaryText)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [HydraTheme.Colors.shellTop, HydraTheme.Colors.navyGlow.opacity(0.9), HydraTheme.Colors.emberGlow.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
