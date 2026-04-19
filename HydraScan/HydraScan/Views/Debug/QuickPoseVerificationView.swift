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
            .padding(24)
        }
        .navigationTitle("Verification Lab")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            viewModel.startLiveVerification()
        }
        .onDisappear {
            viewModel.stopLiveVerification()
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UI Sanity Test")
                .font(.headline)

            if let clipURL = viewModel.clipURL {
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
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                Text("Fixture clip missing from app bundle.")
                    .foregroundStyle(.red)
            }

            Text(viewModel.liveStatusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fixture Test")
                .font(.headline)

            Text("Bundled clip: \(viewModel.clip.displayName)")
                .foregroundStyle(.secondary)

            Text(viewModel.hasConfiguredSDKKey ? "QuickPose SDK key detected in build settings." : "QuickPose SDK key is not configured. QuickPose may return validation errors.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(viewModel.hasConfiguredSDKKey ? .green : .orange)

            HStack {
                Button("Run Fixture Verification") {
                    viewModel.runFixtureVerification()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessingFixture)

                Button("Save Live Artifact") {
                    viewModel.saveLiveArtifactSnapshot()
                }
                .buttonStyle(.bordered)
            }

            if viewModel.isProcessingFixture {
                ProgressView(value: viewModel.fixtureProgress)
                Text("Processing prerecorded clip through QuickPose post-processing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            statRow(label: "SDK version", value: viewModel.sdkVersion)
            statRow(label: "Bundle id", value: viewModel.bundleIdentifier)

            if let fixtureErrorMessage = viewModel.fixtureErrorMessage {
                Text(fixtureErrorMessage)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var liveStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Metrics")
                .font(.headline)

            Group {
                statRow(label: "Frames seen", value: "\(viewModel.liveFrameCount)")
                statRow(label: "Estimated reps", value: "\(viewModel.liveRepCount)")
                statRow(label: "Current asymmetry", value: viewModel.currentAsymmetryText)
            }

            Divider()

            ForEach(viewModel.currentMetrics) { metric in
                statRow(label: metric.name, value: metric.stringValue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var artifactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Artifact Test")
                .font(.headline)

            if let liveArtifactURL = viewModel.liveArtifactURL {
                Text("Latest live JSON: \(liveArtifactURL.path)")
                    .font(.footnote)
                    .textSelection(.enabled)
            }

            if let fixtureArtifactURL = viewModel.fixtureArtifactURL {
                Text("Latest fixture JSON: \(fixtureArtifactURL.path)")
                    .font(.footnote)
                    .textSelection(.enabled)
            }

            if let fixtureOutputMovieURL = viewModel.fixtureOutputMovieURL {
                Text("Latest processed movie: \(fixtureOutputMovieURL.path)")
                    .font(.footnote)
                    .textSelection(.enabled)
            }

            if viewModel.liveArtifactURL == nil, viewModel.fixtureArtifactURL == nil {
                Text("No artifacts saved yet.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics")
                .font(.headline)

            if viewModel.diagnosticMessages.isEmpty {
                Text("No diagnostic events yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.diagnosticMessages.enumerated()), id: \.offset) { _, message in
                    Text(message)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func fixtureResultsSection(summary: QuickPoseVerificationSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fixture Assertions")
                .font(.headline)

            ForEach(summary.assertions) { assertion in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: assertion.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(assertion.passed ? .green : .red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assertion.name)
                            .font(.subheadline.weight(.semibold))
                        Text(assertion.details)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func latestFrameSection(artifact: QuickPoseVerificationFrameArtifact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest Frame Snapshot")
                .font(.headline)

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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func rawLandmarkColumn(artifact: QuickPoseVerificationFrameArtifact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Raw Landmarks")
                .font(.subheadline.weight(.semibold))
            Text("Body points: \(artifact.bodyLandmarks.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(Array(artifact.bodyLandmarks.prefix(5).enumerated()), id: \.offset) { index, point in
                Text("\(index): x \(String(format: "%.3f", point.x)), y \(String(format: "%.3f", point.y)), z \(String(format: "%.3f", point.z))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricColumn(artifact: QuickPoseVerificationFrameArtifact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Computed Metrics")
                .font(.subheadline.weight(.semibold))
            Text("Status: \(artifact.status)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(artifact.metrics) { metric in
                statRow(label: metric.name, value: metric.stringValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        QuickPoseVerificationView()
    }
}
#endif
