import SwiftUI
import Combine
import AVFoundation
import CoreMedia
import UIKit

#if canImport(QuickPoseCore)
import QuickPoseCore

enum QuickPoseRuntimeEnvironment: String {
    case iOSSimulator
    case macDesignedForiPhone
    case physicalDevice

    static var current: QuickPoseRuntimeEnvironment {
#if targetEnvironment(simulator)
        return .iOSSimulator
#else
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return .macDesignedForiPhone
        }
        return .physicalDevice
#endif
    }

    var supportsQuickPoseRuntime: Bool {
        self != .iOSSimulator
    }

    var usesLiveCamera: Bool {
        self == .physicalDevice
    }

    var usesBundledClipPreview: Bool {
        self == .macDesignedForiPhone
    }

    var liveSectionTitle: String {
        switch self {
        case .iOSSimulator:
            return "Live Camera Test"
        case .macDesignedForiPhone:
            return "Mac Runtime Test"
        case .physicalDevice:
            return "Live Camera Test"
        }
    }

    var startupMessage: String {
        switch self {
        case .iOSSimulator:
            return "QuickPose does not run on the iOS Simulator. Use Sri's iPhone or My Mac (Designed for iPhone/iPad)."
        case .macDesignedForiPhone:
            return "Starting QuickPose with the bundled verification clip on My Mac…"
        case .physicalDevice:
            return "Starting QuickPose with the live camera feed…"
        }
    }

    var supportNote: String {
        switch self {
        case .iOSSimulator:
            return "QuickPose's official SDK only compiles for iOS Simulator. Live frames and post-processing require a physical iPhone or a supported Apple silicon Mac runtime."
        case .macDesignedForiPhone:
            return "Running in the Apple silicon Mac runtime. The bundled clip is used here because QuickPose documents this path for local desktop verification."
        case .physicalDevice:
            return "Running on a physical iPhone. Live camera frames and fixture processing should both work here."
        }
    }
}

@MainActor
final class QuickPoseVerificationViewModel: ObservableObject {
    @Published var overlayImage: UIImage?
    @Published var liveStatusText = "Waiting to start QuickPose verification."
    @Published var liveFrameCount = 0
    @Published var liveRepCount = 0
    @Published var currentMetrics: [QuickPoseVerificationMetric] = []
    @Published var currentAsymmetryText = "Unavailable"
    @Published var latestFrameArtifact: QuickPoseVerificationFrameArtifact?
    @Published var liveArtifactURL: URL?
    @Published var fixtureArtifactURL: URL?
    @Published var fixtureOutputMovieURL: URL?
    @Published var fixtureRun: QuickPoseVerificationRun?
    @Published var isProcessingFixture = false
    @Published var fixtureProgress = 0.0
    @Published var fixtureErrorMessage: String?
    @Published var diagnosticMessages: [String] = []
    @Published var sdkVersion = "Unknown"
    @Published var bundleIdentifier = Bundle.main.bundleIdentifier ?? "Unknown"

    let clip: QuickPoseFixtureClip
    let runtimeEnvironment = QuickPoseRuntimeEnvironment.current

    private let service: QuickPoseVerificationService
    private let quickPose: QuickPose
    private var liveFrames: [QuickPoseVerificationFrameArtifact] = []
    private var liveTimeoutTask: Task<Void, Never>?
    private var fixtureTimeoutTask: Task<Void, Never>?
    private var currentFixtureRunID = UUID()
    private var hasLoggedFirstLiveFrame = false

    init(
        clip: QuickPoseFixtureClip = .happyDance,
        service: QuickPoseVerificationService = .shared
    ) {
        self.clip = clip
        self.service = service
        quickPose = QuickPose(sdkKey: HydraScanConstants.quickPoseSDKKey)
        sdkVersion = quickPose.quickPoseVersion()
    }

    var hasConfiguredSDKKey: Bool {
        !HydraScanConstants.quickPoseSDKKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var clipURL: URL? {
        clip.bundleURL
    }

    var supportsQuickPoseRuntime: Bool {
        runtimeEnvironment.supportsQuickPoseRuntime
    }

    var usesLiveCamera: Bool {
        runtimeEnvironment.usesLiveCamera
    }

    var usesBundledClipPreview: Bool {
        runtimeEnvironment.usesBundledClipPreview
    }

    var quickPoseDelegate: QuickPose {
        quickPose
    }

    func startLiveVerification() {
        guard supportsQuickPoseRuntime else {
            liveStatusText = runtimeEnvironment.startupMessage
            appendDiagnostic(runtimeEnvironment.startupMessage)
            return
        }

        if usesBundledClipPreview, clipURL == nil {
            liveStatusText = "Fixture clip is missing from the bundle."
            return
        }

        liveTimeoutTask?.cancel()
        liveFrames = []
        liveFrameCount = 0
        liveRepCount = 0
        overlayImage = nil
        latestFrameArtifact = nil
        currentMetrics = []
        currentAsymmetryText = "Unavailable"
        liveArtifactURL = nil
        hasLoggedFirstLiveFrame = false
        liveStatusText = hasConfiguredSDKKey ? runtimeEnvironment.startupMessage : "QuickPose SDK key is missing. Expect validation errors."
        appendDiagnostic("Live verification requested. SDK v\(sdkVersion), bundle \(bundleIdentifier).")

        quickPose.start(
            features: QuickPoseVerificationAnalyzer.liveFeatures,
            onStart: { [weak self] in
                Task { @MainActor in
                    self?.liveStatusText = "QuickPose engine started. Waiting for frames…"
                    self?.appendDiagnostic("QuickPose live engine reported onStart.")
                }
            },
            onFrame: { [weak self] status, image, features, _, landmarks in
                guard let self else { return }

                let timeSeconds: Double
                switch status {
                case let .success(info):
                    timeSeconds = CMTimeGetSeconds(info.timestamp)
                case let .noPersonFound(info):
                    timeSeconds = CMTimeGetSeconds(info.timestamp)
                case .sdkValidationError:
                    timeSeconds = 0
                }

                let artifact = QuickPoseVerificationAnalyzer.frameArtifact(
                    progress: 0,
                    timeSeconds: timeSeconds,
                    status: status,
                    features: features,
                    landmarks: landmarks
                )

                Task { @MainActor in
                    if !self.hasLoggedFirstLiveFrame {
                        self.hasLoggedFirstLiveFrame = true
                        self.appendDiagnostic("First live callback received with status \(artifact.status).")
                    }

                    self.overlayImage = image
                    self.latestFrameArtifact = artifact
                    self.liveFrames.append(artifact)
                    self.liveFrameCount = self.liveFrames.count
                    self.currentMetrics = QuickPoseVerificationAnalyzer.currentMetrics(from: artifact)
                    self.liveRepCount = QuickPoseVerificationAnalyzer.estimatedRepCount(from: self.liveFrames)

                    if let asymmetry = QuickPoseVerificationAnalyzer.currentAsymmetry(from: artifact) {
                        self.currentAsymmetryText = String(format: "%.1f%%", asymmetry)
                    } else {
                        self.currentAsymmetryText = "Unavailable"
                    }

                    switch status {
                    case .success:
                        self.liveStatusText = "Live verification is receiving frames."
                    case .noPersonFound:
                        self.liveStatusText = "QuickPose is running, but it cannot find a person in the frame."
                    case .sdkValidationError:
                        self.liveStatusText = "QuickPose reported an SDK validation error."
                        self.appendDiagnostic("Live callback reported sdkValidationError.")
                    }
                }
            }
        )

        liveTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self, self.liveFrameCount == 0 else { return }

                self.liveStatusText = "QuickPose started, but no live frames arrived after 5 seconds."
                self.appendDiagnostic("No live callbacks arrived within 5 seconds. This points to SDK validation or runtime processing trouble.")
            }
        }
    }

    func stopLiveVerification(saveArtifact: Bool = true) {
        liveTimeoutTask?.cancel()
        quickPose.stop()
        appendDiagnostic("Live verification stopped after \(liveFrames.count) captured callbacks.")

        guard saveArtifact, !liveFrames.isEmpty else { return }

        let run = QuickPoseVerificationAnalyzer.buildRun(
            clip: clip,
            frames: liveFrames,
            sdkKeyConfigured: hasConfiguredSDKKey,
            outputMovieURL: nil
        )

        Task {
            do {
                let artifactURL = try service.saveRun(run, clip: clip, label: "live")
                await MainActor.run {
                    liveArtifactURL = artifactURL
                    appendDiagnostic("Saved live artifact to \(artifactURL.lastPathComponent).")
                }
            } catch {
                await MainActor.run {
                    liveStatusText = "Unable to save live verification artifact: \(error.localizedDescription)"
                    appendDiagnostic("Saving live artifact failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func saveLiveArtifactSnapshot() {
        stopLiveVerification(saveArtifact: true)
        startLiveVerification()
    }

    func runFixtureVerification() {
        guard supportsQuickPoseRuntime else {
            fixtureErrorMessage = runtimeEnvironment.startupMessage
            appendDiagnostic("Fixture verification skipped: \(runtimeEnvironment.startupMessage)")
            return
        }

        guard let clipURL else {
            fixtureErrorMessage = "Fixture clip is missing from the bundle."
            return
        }

        fixtureTimeoutTask?.cancel()
        isProcessingFixture = true
        fixtureProgress = 0
        fixtureErrorMessage = nil
        fixtureArtifactURL = nil
        fixtureOutputMovieURL = nil
        fixtureRun = nil
        currentFixtureRunID = UUID()
        let runID = currentFixtureRunID

        let clip = clip
        let service = service
        let sdkKey = HydraScanConstants.quickPoseSDKKey
        let fixtureFeatures = QuickPoseVerificationAnalyzer.fixtureFeatures
        let sdkKeyConfigured = hasConfiguredSDKKey
        appendDiagnostic("Fixture verification requested for \(clip.displayName).")

        fixtureTimeoutTask = Task { [weak self, runID] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self, self.currentFixtureRunID == runID, self.isProcessingFixture else { return }

                self.fixtureErrorMessage = "QuickPose fixture processing has not produced a callback after 15 seconds."
                self.isProcessingFixture = false
                self.appendDiagnostic("Fixture verification timed out waiting for QuickPose callbacks.")
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self, clip, clipURL, sdkKey, sdkKeyConfigured, service, fixtureFeatures, runID] in
            do {
                let outputMovieURL = try service.nextOutputMovieURL(for: clip)
                let processor = QuickPosePostProcessor(sdkKey: sdkKey)
                let request = QuickPosePostProcessor.Request(
                    input: clipURL,
                    output: outputMovieURL,
                    outputType: .mov
                )
                var frames: [QuickPoseVerificationFrameArtifact] = []

                Task { @MainActor [weak self] in
                    self?.appendDiagnostic("Fixture processor started. Output movie: \(outputMovieURL.lastPathComponent).")
                }

                try processor.process(
                    features: fixtureFeatures,
                    isFrontCamera: false,
                    request: request
                ) { progress, time, status, _, features, _, landmarks in
                    let artifact = QuickPoseVerificationAnalyzer.frameArtifact(
                        progress: progress,
                        timeSeconds: time,
                        status: status,
                        features: features,
                        landmarks: landmarks
                    )
                    frames.append(artifact)

                    Task { @MainActor [weak self] in
                        guard let self, self.currentFixtureRunID == runID else { return }

                        if frames.count == 1 {
                            self.appendDiagnostic("First fixture callback received with status \(artifact.status).")
                        }
                        self.fixtureProgress = progress
                        self.latestFrameArtifact = artifact
                    }
                }

                let run = QuickPoseVerificationAnalyzer.buildRun(
                    clip: clip,
                    frames: frames,
                    sdkKeyConfigured: sdkKeyConfigured,
                    outputMovieURL: outputMovieURL
                )
                let artifactURL = try service.saveRun(run, clip: clip, label: "fixture")

                Task { @MainActor [weak self] in
                    guard let self, self.currentFixtureRunID == runID else { return }

                    self.fixtureTimeoutTask?.cancel()
                    self.fixtureRun = run
                    self.fixtureArtifactURL = artifactURL
                    self.fixtureOutputMovieURL = outputMovieURL
                    self.isProcessingFixture = false
                    self.fixtureProgress = 1
                    self.appendDiagnostic("Fixture verification completed with \(run.summary.successFrames) successful frames.")
                }
            } catch {
                Task { @MainActor [weak self] in
                    guard let self, self.currentFixtureRunID == runID else { return }

                    self.fixtureTimeoutTask?.cancel()
                    self.fixtureErrorMessage = error.localizedDescription
                    self.isProcessingFixture = false
                    self.appendDiagnostic("Fixture verification failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func appendDiagnostic(_ message: String) {
        let timestamp = Date.now.formatted(date: .omitted, time: .standard)
        diagnosticMessages.insert("[\(timestamp)] \(message)", at: 0)
        diagnosticMessages = Array(diagnosticMessages.prefix(12))
    }
}
#endif
