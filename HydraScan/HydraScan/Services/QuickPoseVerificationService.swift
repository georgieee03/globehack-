import Foundation

#if canImport(QuickPoseCore)
import QuickPoseCore

enum QuickPoseVerificationAnalyzer {
    nonisolated static let rightShoulderFeature = QuickPose.Feature.rangeOfMotion(.shoulder(side: .right, clockwiseDirection: true))
    nonisolated static let leftShoulderFeature = QuickPose.Feature.rangeOfMotion(.shoulder(side: .left, clockwiseDirection: false))
    nonisolated static let rightHipFeature = QuickPose.Feature.rangeOfMotion(.hip(side: .right, clockwiseDirection: true))
    nonisolated static let leftHipFeature = QuickPose.Feature.rangeOfMotion(.hip(side: .left, clockwiseDirection: false))
    nonisolated static let rightKneeFeature = QuickPose.Feature.rangeOfMotion(.knee(side: .right, clockwiseDirection: true))
    nonisolated static let leftKneeFeature = QuickPose.Feature.rangeOfMotion(.knee(side: .left, clockwiseDirection: false))
    nonisolated static let backFeature = QuickPose.Feature.rangeOfMotion(.back(clockwiseDirection: false))
    nonisolated static let neckFeature = QuickPose.Feature.rangeOfMotion(.neck(clockwiseDirection: false))
    nonisolated static let overlayFeature = QuickPose.Feature.showPoints()
    nonisolated static let liveFeatures: [QuickPose.Feature] = [
        overlayFeature,
        rightShoulderFeature,
        leftShoulderFeature,
    ]
    nonisolated static let fixtureFeatures: [QuickPose.Feature] = [
        rightShoulderFeature,
        leftShoulderFeature,
    ]
    nonisolated static let captureFeatures: [QuickPose.Feature] = [
        overlayFeature,
        rightShoulderFeature,
        leftShoulderFeature,
        rightHipFeature,
        leftHipFeature,
        rightKneeFeature,
        leftKneeFeature,
        backFeature,
        neckFeature,
    ]

    nonisolated static func frameArtifact(
        progress: Double,
        timeSeconds: Double,
        status: QuickPose.Status,
        features: [QuickPose.Feature: QuickPose.FeatureResult],
        landmarks: QuickPose.Landmarks?
    ) -> QuickPoseVerificationFrameArtifact {
        let metrics = normalizedMetrics(from: features)
        let (statusName, fps, latencyMilliseconds) = unpack(status: status)

        return QuickPoseVerificationFrameArtifact(
            id: UUID(),
            progress: progress,
            timeSeconds: timeSeconds,
            status: statusName,
            fps: fps,
            latencyMilliseconds: latencyMilliseconds,
            metrics: metrics,
            bodyLandmarks: landmarks?.allLandmarksForBody().map(pointArtifact(from:)) ?? [],
            worldBodyLandmarks: landmarks?.allWorldLandmarksForBody().map(pointArtifact(from:)) ?? []
        )
    }

    nonisolated static func buildRun(
        clip: QuickPoseFixtureClip,
        frames: [QuickPoseVerificationFrameArtifact],
        sdkKeyConfigured: Bool,
        outputMovieURL: URL?
    ) -> QuickPoseVerificationRun {
        let rightROMSamples = samples(named: "Right Shoulder", from: frames)
        let leftROMSamples = samples(named: "Left Shoulder", from: frames)
        let asymmetrySamples = samples(named: "Shoulder ROM Asymmetry", from: frames)
        let successFrames = frames.filter { $0.status == "success" }.count
        let noPersonFrames = frames.filter { $0.status == "no_person_found" }.count
        let validationErrorFrames = frames.filter { $0.status == "sdk_validation_error" }.count
        let estimatedRepCount = estimateRepCount(from: rightROMSamples)

        let assertions = [
            QuickPoseVerificationAssertion(
                name: "SDK key configured",
                passed: sdkKeyConfigured,
                details: sdkKeyConfigured ? "QuickPose SDK key was found in build settings." : "No QuickPose SDK key is configured for this app build."
            ),
            QuickPoseVerificationAssertion(
                name: "Frames processed",
                passed: successFrames >= 10,
                details: successFrames > 0 ? "Processed \(successFrames) successful frames." : "QuickPose did not report any successful frames."
            ),
            QuickPoseVerificationAssertion(
                name: "ROM extracted",
                passed: maxValue(in: rightROMSamples + leftROMSamples) ?? 0 >= 10,
                details: metricDetails(label: "Max shoulder ROM", value: maxValue(in: rightROMSamples + leftROMSamples), suffix: "deg")
            ),
            QuickPoseVerificationAssertion(
                name: "Rep estimate detected",
                passed: estimatedRepCount >= 1,
                details: "Estimated reps: \(estimatedRepCount)"
            ),
            QuickPoseVerificationAssertion(
                name: "Asymmetry computed",
                passed: maxValue(in: asymmetrySamples) != nil,
                details: metricDetails(label: "Peak asymmetry", value: maxValue(in: asymmetrySamples), suffix: "%")
            ),
        ]

        return QuickPoseVerificationRun(
            summary: QuickPoseVerificationSummary(
                clipName: clip.displayName,
                totalFrames: frames.count,
                successFrames: successFrames,
                noPersonFrames: noPersonFrames,
                validationErrorFrames: validationErrorFrames,
                maxRightShoulderROM: maxValue(in: rightROMSamples),
                maxLeftShoulderROM: maxValue(in: leftROMSamples),
                maxAsymmetryPercent: maxValue(in: asymmetrySamples),
                estimatedRepCount: estimatedRepCount,
                sdkKeyConfigured: sdkKeyConfigured,
                outputMovieFilename: outputMovieURL?.lastPathComponent,
                assertions: assertions,
                generatedAt: Date()
            ),
            frames: frames
        )
    }

    nonisolated static func currentMetrics(from frame: QuickPoseVerificationFrameArtifact?) -> [QuickPoseVerificationMetric] {
        frame?.metrics ?? []
    }

    nonisolated static func estimatedRepCount(from frames: [QuickPoseVerificationFrameArtifact]) -> Int {
        estimateRepCount(from: samples(named: "Right Shoulder", from: frames))
    }

    nonisolated static func currentAsymmetry(from frame: QuickPoseVerificationFrameArtifact?) -> Double? {
        frame?.metrics.first(where: { $0.name == "Shoulder ROM Asymmetry" })?.value
    }

    nonisolated private static func unpack(status: QuickPose.Status) -> (String, Int?, Double?) {
        switch status {
        case let .success(info):
            return ("success", info.fps, info.latency * 1000)
        case let .noPersonFound(info):
            return ("no_person_found", info.fps, info.latency * 1000)
        case .sdkValidationError:
            return ("sdk_validation_error", nil, nil)
        }
    }

    nonisolated private static func normalizedMetrics(from features: [QuickPose.Feature: QuickPose.FeatureResult]) -> [QuickPoseVerificationMetric] {
        var metrics = features
            .map { feature, result in
                QuickPoseVerificationMetric(
                    name: feature.displayString,
                    value: result.value,
                    stringValue: result.stringValue
                )
            }
            .sorted { $0.name < $1.name }

        if
            let right = features[rightShoulderFeature]?.value,
            let left = features[leftShoulderFeature]?.value
        {
            let dominantROM = max(max(abs(right), abs(left)), 1)
            let asymmetry = abs(right - left) / dominantROM * 100
            metrics.append(
                QuickPoseVerificationMetric(
                    name: "Shoulder ROM Asymmetry",
                    value: asymmetry,
                    stringValue: String(format: "%.1f%%", asymmetry)
                )
            )
        }

        return metrics
    }

    nonisolated private static func pointArtifact(from point: QuickPose.Point3d) -> QuickPoseVerificationPoint {
        QuickPoseVerificationPoint(
            x: point.x,
            y: point.y,
            z: point.z,
            visibility: point.visibility,
            presence: point.presence,
            cameraAspectY: point.cameraAspectY
        )
    }

    nonisolated private static func samples(named name: String, from frames: [QuickPoseVerificationFrameArtifact]) -> [Double] {
        frames.compactMap { frame in
            frame.metrics.first(where: { $0.name == name })?.value
        }
    }

    nonisolated private static func maxValue(in samples: [Double]) -> Double? {
        samples.max()
    }

    nonisolated private static func metricDetails(label: String, value: Double?, suffix: String) -> String {
        guard let value else {
            return "\(label): unavailable"
        }

        return "\(label): \(String(format: "%.1f", value)) \(suffix)"
    }

    nonisolated private static func estimateRepCount(from samples: [Double]) -> Int {
        guard
            let minimum = samples.min(),
            let maximum = samples.max(),
            maximum - minimum >= 10
        else {
            return 0
        }

        let highThreshold = minimum + ((maximum - minimum) * 0.7)
        let lowThreshold = minimum + ((maximum - minimum) * 0.35)
        var count = 0
        var isAboveHighThreshold = false

        for sample in samples {
            if !isAboveHighThreshold, sample >= highThreshold {
                isAboveHighThreshold = true
            } else if isAboveHighThreshold, sample <= lowThreshold {
                count += 1
                isAboveHighThreshold = false
            }
        }

        return count
    }
}

final class QuickPoseVerificationService {
    nonisolated static let shared = QuickPoseVerificationService()

    func nextOutputMovieURL(for clip: QuickPoseFixtureClip) throws -> URL {
        try artifactsDirectoryURL().appendingPathComponent("\(clip.rawValue)-processed-\(timestamp()).mov")
    }

    func saveRun(_ run: QuickPoseVerificationRun, clip: QuickPoseFixtureClip, label: String) throws -> URL {
        let destinationURL = try artifactsDirectoryURL().appendingPathComponent("\(clip.rawValue)-\(label)-\(timestamp()).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(run).write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    private func artifactsDirectoryURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL
            .appendingPathComponent("HydraScan", isDirectory: true)
            .appendingPathComponent("QuickPoseVerification", isDirectory: true)

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    }
}
#endif
