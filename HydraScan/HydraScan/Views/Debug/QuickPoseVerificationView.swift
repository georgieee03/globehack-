import Foundation
import SwiftUI
import AVFoundation

#if canImport(QuickPoseCore) && canImport(QuickPoseSwiftUI)
import QuickPoseCore
import QuickPoseSwiftUI

struct QuickPoseVerificationView: View {
    @StateObject private var viewModel = QuickPoseVerificationViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HydraPageHeader(
                    eyebrow: "Verification Lab",
                    title: "Validate the live QuickPose pipeline.",
                    subtitle: "Inspect the real-time overlay, fixture processing path, saved artifacts, and device-level metrics in one branded developer surface."
                )

                previewSection
                controlSection
                liveStatsSection
                artifactSection
                diagnosticsSection

                if let run = viewModel.fixtureRun {
                    fixtureResultsSection(summary: run.summary)
                }

                if let latestFrameArtifact = viewModel.latestFrameArtifact {
                    latestFrameSection(artifact: latestFrameArtifact)
                }
            }
            .padding(HydraTheme.Spacing.page)
        }
        .toolbar(.hidden, for: .navigationBar)
        .hydraShell()
        .onAppear {
            viewModel.startLiveVerification()
        }
        .onDisappear {
            viewModel.stopLiveVerification()
        }
    }

    private var previewSection: some View {
        HydraCard {
            Text(viewModel.runtimeEnvironment.liveSectionTitle)
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            if viewModel.usesLiveCamera {
                ZStack {
                    QuickPoseCameraView(
                        useFrontCamera: true,
                        delegate: viewModel.quickPoseDelegate,
                        videoGravity: .resizeAspectFill
                    )
                    QuickPoseOverlayView(overlayImage: $viewModel.overlayImage, contentMode: .fit)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .background(HydraTheme.Colors.shell)
                .clipShape(RoundedRectangle(cornerRadius: HydraTheme.Radius.media, style: .continuous))
            } else if let clipURL = viewModel.clipURL, viewModel.usesBundledClipPreview {
                ZStack {
                    QuickPoseSimulatedCameraView(
                        useFrontCamera: false,
                        delegate: viewModel.quickPoseDelegate,
                        video: clipURL,
                        videoGravity: .resizeAspect
                    )
                    QuickPoseOverlayView(overlayImage: $viewModel.overlayImage, contentMode: .fit)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .background(HydraTheme.Colors.shell)
                .clipShape(RoundedRectangle(cornerRadius: HydraTheme.Radius.media, style: .continuous))
            } else {
                HydraStatusBanner(message: viewModel.runtimeEnvironment.supportNote, tone: .warning, icon: "camera.fill")
            }

            Text(viewModel.runtimeEnvironment.supportNote)
                .font(HydraTypography.body(13, weight: .medium))
                .foregroundStyle(HydraTheme.Colors.secondaryText)

            Text(viewModel.liveStatusText)
                .font(HydraTypography.body(15))
                .foregroundStyle(HydraTheme.Colors.secondaryText)
        }
    }

    private var controlSection: some View {
        HydraCard(role: .panel) {
            Text("Fixture Test")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            Text("Bundled clip: \(viewModel.clip.displayName)")
                .font(HydraTypography.body(15))
                .foregroundStyle(HydraTheme.Colors.secondaryText)

            Text(viewModel.hasConfiguredSDKKey ? "QuickPose SDK key detected in build settings." : "QuickPose SDK key is not configured. QuickPose may return validation errors.")
                .font(HydraTypography.body(14, weight: .semibold))
                .foregroundStyle(viewModel.hasConfiguredSDKKey ? HydraTheme.Colors.success : HydraTheme.Colors.warning)

            HStack {
                Button("Run Fixture Verification") {
                    viewModel.runFixtureVerification()
                }
                .buttonStyle(HydraButtonStyle(kind: .primary))
                .disabled(viewModel.isProcessingFixture || !viewModel.supportsQuickPoseRuntime)

                Button("Save Live Artifact") {
                    viewModel.saveLiveArtifactSnapshot()
                }
                .buttonStyle(HydraButtonStyle(kind: .secondary))
                .disabled(!viewModel.supportsQuickPoseRuntime)
            }

            if viewModel.isProcessingFixture {
                ProgressView(value: viewModel.fixtureProgress)
                Text("Processing prerecorded clip through QuickPose post-processing.")
                    .font(HydraTypography.body(13))
                    .foregroundStyle(HydraTheme.Colors.secondaryText)
            }

            HydraMetricRow(label: "SDK version", value: viewModel.sdkVersion)
            HydraMetricRow(label: "Bundle id", value: viewModel.bundleIdentifier)

            if let fixtureErrorMessage = viewModel.fixtureErrorMessage {
                HydraStatusBanner(message: fixtureErrorMessage, tone: .error, icon: "exclamationmark.triangle.fill")
            }
        }
    }

    private var liveStatsSection: some View {
        HydraCard(role: .panel) {
            Text("Live Metrics")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            Group {
                HydraMetricRow(label: "Frames seen", value: "\(viewModel.liveFrameCount)")
                HydraMetricRow(label: "Estimated reps", value: "\(viewModel.liveRepCount)")
                HydraMetricRow(label: "Current asymmetry", value: viewModel.currentAsymmetryText)
            }

            Rectangle()
                .fill(HydraTheme.Colors.stroke)
                .frame(height: 1)

            ForEach(viewModel.currentMetrics) { metric in
                HydraMetricRow(label: metric.name, value: metric.stringValue)
            }
        }
    }

    private var artifactSection: some View {
        HydraCard(role: .ivory) {
            Text("Debug Artifact Test")
                .font(HydraTypography.section(28))
                .foregroundStyle(HydraTheme.Colors.ink)

            if let liveArtifactURL = viewModel.liveArtifactURL {
                Text("Latest live JSON: \(liveArtifactURL.path)")
                    .font(HydraTypography.body(13, weight: .medium))
                    .foregroundStyle(HydraTheme.Colors.inkSecondary)
                    .textSelection(.enabled)
            }

            if let fixtureArtifactURL = viewModel.fixtureArtifactURL {
                Text("Latest fixture JSON: \(fixtureArtifactURL.path)")
                    .font(HydraTypography.body(13, weight: .medium))
                    .foregroundStyle(HydraTheme.Colors.inkSecondary)
                    .textSelection(.enabled)
            }

            if let fixtureOutputMovieURL = viewModel.fixtureOutputMovieURL {
                Text("Latest processed movie: \(fixtureOutputMovieURL.path)")
                    .font(HydraTypography.body(13, weight: .medium))
                    .foregroundStyle(HydraTheme.Colors.inkSecondary)
                    .textSelection(.enabled)
            }

            if viewModel.liveArtifactURL == nil, viewModel.fixtureArtifactURL == nil {
                HydraEmptyState(
                    title: "No artifacts saved yet.",
                    message: "Run the fixture verifier or save a live snapshot to inspect processed JSON and exported media from this device.",
                    icon: "tray.full",
                    eyebrow: "Artifact Output",
                    role: .ivory
                )
            }
        }
    }

    private var diagnosticsSection: some View {
        HydraCard {
            Text("Diagnostics")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            if viewModel.diagnosticMessages.isEmpty {
                HydraEmptyState(
                    title: "No diagnostic events yet.",
                    message: "As the runtime starts, processes a fixture, or saves artifacts, detailed verification logs will appear here.",
                    icon: "terminal",
                    eyebrow: "Runtime Events"
                )
            } else {
                ForEach(Array(viewModel.diagnosticMessages.enumerated()), id: \.offset) { _, message in
                    Text(message)
                        .font(HydraTypography.mono(12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(HydraTheme.Colors.secondaryText)
                }
            }
        }
    }

    private func fixtureResultsSection(summary: QuickPoseVerificationSummary) -> some View {
        HydraCard {
            Text("Fixture Assertions")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            ForEach(summary.assertions) { assertion in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: assertion.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(assertion.passed ? HydraTheme.Colors.success : HydraTheme.Colors.error)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assertion.name)
                            .font(HydraTypography.ui(15, weight: .semibold))
                            .foregroundStyle(HydraTheme.Colors.primaryText)
                        Text(assertion.details)
                            .font(HydraTypography.body(13))
                            .foregroundStyle(HydraTheme.Colors.secondaryText)
                    }
                }
            }
        }
    }

    private func latestFrameSection(artifact: QuickPoseVerificationFrameArtifact) -> some View {
        HydraCard(role: .panel) {
            Text("Latest Frame Snapshot")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            ViewThatFits {
                HStack(alignment: .top, spacing: 16) {
                    rawLandmarkColumn(artifact: artifact)
                    metricColumn(artifact: artifact)
                }

                VStack(alignment: .leading, spacing: 16) {
                    rawLandmarkColumn(artifact: artifact)
                    metricColumn(artifact: artifact)
                }
            }
        }
    }

    private func rawLandmarkColumn(artifact: QuickPoseVerificationFrameArtifact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Raw Landmarks")
                .font(HydraTypography.ui(15, weight: .semibold))
                .foregroundStyle(HydraTheme.Colors.primaryText)
            Text("Body points: \(artifact.bodyLandmarks.count)")
                .font(HydraTypography.body(13))
                .foregroundStyle(HydraTheme.Colors.secondaryText)

            ForEach(Array(artifact.bodyLandmarks.prefix(5).enumerated()), id: \.offset) { index, point in
                Text("\(index): x \(String(format: "%.3f", point.x)), y \(String(format: "%.3f", point.y)), z \(String(format: "%.3f", point.z))")
                    .font(HydraTypography.mono(12))
                    .foregroundStyle(HydraTheme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricColumn(artifact: QuickPoseVerificationFrameArtifact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Computed Metrics")
                .font(HydraTypography.ui(15, weight: .semibold))
                .foregroundStyle(HydraTheme.Colors.primaryText)
            Text("Status: \(artifact.status)")
                .font(HydraTypography.body(13))
                .foregroundStyle(HydraTheme.Colors.secondaryText)

            ForEach(artifact.metrics) { metric in
                HydraMetricRow(label: metric.name, value: metric.stringValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        QuickPoseVerificationView()
    }
}
#endif
