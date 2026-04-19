import Combine
import CoreMedia
import Foundation
import UIKit

#if canImport(QuickPoseCore)
import QuickPoseCore
#endif

enum CaptureFlowState: Equatable {
    case idle
    case capturing
    case results
}

enum AssessmentPersistenceState: Equatable {
    case uploaded(String)
    case cachedOffline(String)

    var message: String {
        switch self {
        case let .uploaded(message), let .cachedOffline(message):
            return message
        }
    }
}

private struct PosePointSample {
    let x: Double
    let y: Double
    let z: Double
    let visibility: Double
    let presence: Double

    func distance(to other: PosePointSample) -> Double {
        hypot(x - other.x, y - other.y)
    }
}

private struct CapturedPoseFrame {
    let artifact: QuickPoseVerificationFrameArtifact
    let shoulderMid: PosePointSample?
    let hipMid: PosePointSample?
    let leftShoulder: PosePointSample?
    let rightShoulder: PosePointSample?
    let leftHip: PosePointSample?
    let rightHip: PosePointSample?
    let leftAnkle: PosePointSample?
    let rightAnkle: PosePointSample?
}

private struct CapturedAssessmentData {
    let quickPoseResult: QuickPoseResult
    let romValues: [String: Double]
    let asymmetryScores: [String: Double]
    let movementQualityScores: [String: Double]
    let gaitMetrics: [String: Double]
    let recoveryGraphMetrics: [String: Double]
}

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var flowState: CaptureFlowState = .idle
    @Published var currentStepIndex = 0
    @Published var remainingSeconds = 0
    @Published var repCount = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var latestAssessment: Assessment?
    @Published var persistenceState: AssessmentPersistenceState?
    @Published var overlayImage: UIImage?
    @Published var liveStatusText = "Step into frame to preview your movement scan."
    @Published var currentMetrics: [QuickPoseVerificationMetric] = []
    @Published var capturedFrameCount = 0

    let user: HydraUser
    let profile: ClientProfile
    let captureSteps: [CaptureStepDefinition]

    private let service: SupabaseServiceProtocol
    private let offlineCacheService: OfflineCacheServiceProtocol
    private var captureTask: Task<Void, Never>?
    private var captureStartedAt: Date?

    #if canImport(QuickPoseCore)
    private let runtimeEnvironment = QuickPoseRuntimeEnvironment.current
    private let quickPose: QuickPose
    private var quickPoseRunning = false
    private var capturedFramesByStep: [CaptureStep: [CapturedPoseFrame]] = [:]
    private var allCapturedFrames: [CapturedPoseFrame] = []
    private var liveTimeoutTask: Task<Void, Never>?
    #endif

    init(
        user: HydraUser,
        profile: ClientProfile,
        service: SupabaseServiceProtocol,
        offlineCacheService: OfflineCacheServiceProtocol = OfflineCacheService.shared
    ) {
        self.user = user
        self.profile = profile
        captureSteps = HydraScanConstants.captureSteps(for: profile.primaryRegions)
        self.service = service
        self.offlineCacheService = offlineCacheService
        remainingSeconds = captureSteps.first?.durationSeconds ?? 0

        #if canImport(QuickPoseCore)
        quickPose = QuickPose(sdkKey: HydraScanConstants.quickPoseSDKKey)
        #endif
    }

    var currentStep: CaptureStepDefinition {
        captureSteps[min(currentStepIndex, captureSteps.count - 1)]
    }

    var progressValue: Double {
        guard !captureSteps.isEmpty else { return 0 }
        return Double(currentStepIndex + (flowState == .results ? 1 : 0)) / Double(captureSteps.count)
    }

    var hasConfiguredSDKKey: Bool {
        !HydraScanConstants.quickPoseSDKKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var supportsQuickPoseRuntime: Bool {
        #if canImport(QuickPoseCore)
        runtimeEnvironment.supportsQuickPoseRuntime
        #else
        false
        #endif
    }

    var usesLiveCamera: Bool {
        #if canImport(QuickPoseCore)
        runtimeEnvironment.usesLiveCamera
        #else
        false
        #endif
    }

    var usesBundledClipPreview: Bool {
        #if canImport(QuickPoseCore)
        runtimeEnvironment.usesBundledClipPreview
        #else
        false
        #endif
    }

    var supportNote: String {
        #if canImport(QuickPoseCore)
        runtimeEnvironment.supportNote
        #else
        "QuickPose is unavailable in this build."
        #endif
    }

    var previewClipURL: URL? {
        #if canImport(QuickPoseCore)
        QuickPoseFixtureClip.happyDance.bundleURL
        #else
        nil
        #endif
    }

    #if canImport(QuickPoseCore)
    var quickPoseDelegate: QuickPose {
        quickPose
    }
    #endif

    func startQuickPosePreview() {
        #if canImport(QuickPoseCore)
        guard supportsQuickPoseRuntime else {
            liveStatusText = runtimeEnvironment.startupMessage
            return
        }

        guard hasConfiguredSDKKey else {
            liveStatusText = "QuickPose SDK key is missing from this build."
            return
        }

        guard !quickPoseRunning else { return }
        quickPoseRunning = true
        liveStatusText = runtimeEnvironment.startupMessage

        quickPose.start(
            features: QuickPoseVerificationAnalyzer.captureFeatures,
            onStart: { [weak self] in
                Task { @MainActor in
                    self?.liveStatusText = "QuickPose is ready. Start capture when you are centered in frame."
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
                let capturedFrame = self.makeCapturedFrame(artifact: artifact, landmarks: landmarks)

                Task { @MainActor in
                    self.overlayImage = image
                    self.currentMetrics = self.filteredMetrics(for: artifact, step: self.currentStep.step)

                    switch status {
                    case .success:
                        self.liveStatusText = self.flowState == .capturing
                            ? "Capturing \(self.currentStep.title.lowercased())."
                            : "QuickPose is tracking your joints. Start when ready."
                    case .noPersonFound:
                        self.liveStatusText = "QuickPose is on, but it cannot see your full body. Step back into frame."
                    case .sdkValidationError:
                        self.liveStatusText = "QuickPose reported an SDK validation error."
                    }

                    guard self.flowState == .capturing, artifact.status == "success" else { return }

                    self.allCapturedFrames.append(capturedFrame)
                    self.capturedFramesByStep[self.currentStep.step, default: []].append(capturedFrame)
                    self.capturedFrameCount = self.allCapturedFrames.count
                    self.repCount = self.estimatedRepCount(for: self.currentStep.step)
                }
            }
        )

        liveTimeoutTask?.cancel()
        liveTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self, self.overlayImage == nil else { return }
                self.liveStatusText = "QuickPose started, but no frames arrived yet."
            }
        }
        #else
        liveStatusText = "QuickPose is unavailable in this build."
        #endif
    }

    func stopQuickPosePreview() {
        captureTask?.cancel()

        #if canImport(QuickPoseCore)
        liveTimeoutTask?.cancel()
        quickPose.stop()
        quickPoseRunning = false
        #endif
    }

    func startCapture() {
        guard supportsQuickPoseRuntime else {
            errorMessage = supportNote
            return
        }

        guard hasConfiguredSDKKey else {
            errorMessage = "QuickPose SDK key is missing from this build."
            return
        }

        startQuickPosePreview()
        resetCaptureSession()

        flowState = .capturing
        errorMessage = nil
        currentStepIndex = 0
        remainingSeconds = currentStep.durationSeconds
        liveStatusText = "Capturing \(currentStep.title.lowercased())."
        captureStartedAt = Date()

        captureTask?.cancel()
        captureTask = Task {
            await runCaptureSequence()
        }
    }

    func skipToResults() {
        captureTask?.cancel()
        Task {
            await finalizeCapture()
        }
    }

    func reset() {
        captureTask?.cancel()
        resetCaptureSession()
        flowState = .idle
        remainingSeconds = captureSteps.first?.durationSeconds ?? 0
        errorMessage = nil
        liveStatusText = supportsQuickPoseRuntime
            ? "QuickPose is tracking your joints. Start when ready."
            : supportNote
    }

    private func runCaptureSequence() async {
        for (index, step) in captureSteps.enumerated() {
            guard !Task.isCancelled else { return }

            currentStepIndex = index
            remainingSeconds = step.durationSeconds
            repCount = 0
            liveStatusText = "Capturing \(step.title.lowercased()). \(step.instruction)"

            for second in stride(from: step.durationSeconds, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                remainingSeconds = second
                try? await Task.sleep(for: .seconds(1))
            }
        }

        await finalizeCapture()
    }

    private func finalizeCapture() async {
        isLoading = true
        errorMessage = nil
        persistenceState = nil

        guard let captureData = buildAssessmentData() else {
            isLoading = false
            flowState = .idle
            errorMessage = "No QuickPose frames were captured. Step fully into frame and try again."
            return
        }

        let assessment = Assessment(
            id: UUID(),
            clientID: user.id,
            clinicID: user.clinicID,
            practitionerID: nil,
            assessmentType: .preSession,
            quickPoseData: captureData.quickPoseResult,
            romValues: captureData.romValues,
            asymmetryScores: captureData.asymmetryScores,
            movementQualityScores: captureData.movementQualityScores,
            gaitMetrics: captureData.gaitMetrics,
            heartRate: nil,
            breathRate: nil,
            hrvRMSSD: profile.wearableHRV,
            bodyZones: profile.primaryRegions,
            recoveryGoal: profile.goals.first,
            subjectiveBaseline: SubjectiveBaseline(
                stiffness: profile.recoverySignals.first?.severity,
                soreness: profile.recoverySignals.dropFirst().first?.severity,
                notes: profile.activityContext
            ),
            recoveryMap: buildRecoveryMap(
                romValues: captureData.romValues,
                asymmetryScores: captureData.asymmetryScores
            ),
            recoveryGraphDelta: captureData.recoveryGraphMetrics,
            createdAt: Date()
        )

        do {
            let uploadedAssessment = try await service.createAssessment(assessment)
            persistenceState = .uploaded("Assessment saved to your recovery timeline.")
            latestAssessment = uploadedAssessment
            flowState = .results
        } catch {
            do {
                try await offlineCacheService.cacheAssessment(assessment)
                persistenceState = .cachedOffline("No connection? This assessment is saved on this device and can sync automatically later.")
                latestAssessment = assessment
                flowState = .results
            } catch {
                errorMessage = error.localizedDescription
                flowState = .idle
            }
        }

        isLoading = false
    }

    private func resetCaptureSession() {
        persistenceState = nil
        latestAssessment = nil
        currentStepIndex = 0
        capturedFrameCount = 0
        currentMetrics = []
        overlayImage = nil
        repCount = 0
        captureStartedAt = nil

        #if canImport(QuickPoseCore)
        capturedFramesByStep = [:]
        allCapturedFrames = []
        #endif
    }

    private func buildAssessmentData() -> CapturedAssessmentData? {
        #if canImport(QuickPoseCore)
        let shoulderFrames = successfulFrames(for: [.standingFront, .shoulderFlexion])
        let squatFrames = successfulFrames(for: [.squat])
        let hipHingeFrames = successfulFrames(for: [.standingSide, .hipHinge])
        let rightBalanceFrames = successfulFrames(for: [.singleLegBalanceRight])
        let leftBalanceFrames = successfulFrames(for: [.singleLegBalanceLeft])
        let allFrames = successfulFrames(for: CaptureStep.allCases)

        guard !allFrames.isEmpty else { return nil }

        let romValues = compactMetrics([
            ("right_shoulder_flexion", maxMetric(named: "Right Shoulder", in: shoulderFrames)),
            ("left_shoulder_flexion", maxMetric(named: "Left Shoulder", in: shoulderFrames)),
            ("right_hip_flexion", maxMetric(named: "Right Hip", in: hipHingeFrames + squatFrames)),
            ("left_hip_flexion", maxMetric(named: "Left Hip", in: hipHingeFrames + squatFrames)),
            ("right_knee_flexion", maxMetric(named: "Right Knee", in: squatFrames)),
            ("left_knee_flexion", maxMetric(named: "Left Knee", in: squatFrames)),
            ("back_flexion", maxMetric(named: "Back", in: hipHingeFrames)),
            ("neck_flexion", maxMetric(named: "Neck", in: allFrames)),
        ])

        let asymmetryScores = compactMetrics([
            ("shoulder_flexion", maxMetric(named: "Shoulder ROM Asymmetry", in: shoulderFrames)),
            ("hip_flexion", asymmetryPercentage(
                right: maxMetric(named: "Right Hip", in: hipHingeFrames + squatFrames),
                left: maxMetric(named: "Left Hip", in: hipHingeFrames + squatFrames)
            )),
            ("knee_flexion", asymmetryPercentage(
                right: maxMetric(named: "Right Knee", in: squatFrames),
                left: maxMetric(named: "Left Knee", in: squatFrames)
            )),
            ("single_leg_balance", asymmetryPercentage(
                right: stabilityScore(for: rightBalanceFrames),
                left: stabilityScore(for: leftBalanceFrames)
            )),
        ])

        let movementQualityScores = compactMetrics([
            ("standing_front", standingQuality(for: successfulFrames(for: [.standingFront]))),
            ("standing_side", standingQuality(for: successfulFrames(for: [.standingSide]))),
            ("shoulder_flexion", shoulderFlexionQuality(for: shoulderFrames)),
            ("squat", squatQuality(for: squatFrames)),
            ("hip_hinge", hipHingeQuality(for: hipHingeFrames)),
            ("single_leg_balance_right", stabilityScore(for: rightBalanceFrames)),
            ("single_leg_balance_left", stabilityScore(for: leftBalanceFrames)),
        ])

        let rightBalanceSway = normalizedSway(for: rightBalanceFrames)
        let leftBalanceSway = normalizedSway(for: leftBalanceFrames)
        let gaitMetrics = compactMetrics([
            ("right_balance_sway", rightBalanceSway),
            ("left_balance_sway", leftBalanceSway),
            ("front_posture_symmetry", postureSymmetryScore(for: successfulFrames(for: [.standingFront]))),
        ])

        let jointAngles = compactMetrics([
            ("right_shoulder_current", latestMetric(named: "Right Shoulder", in: shoulderFrames)),
            ("left_shoulder_current", latestMetric(named: "Left Shoulder", in: shoulderFrames)),
            ("right_hip_current", latestMetric(named: "Right Hip", in: hipHingeFrames + squatFrames)),
            ("left_hip_current", latestMetric(named: "Left Hip", in: hipHingeFrames + squatFrames)),
            ("right_knee_current", latestMetric(named: "Right Knee", in: squatFrames)),
            ("left_knee_current", latestMetric(named: "Left Knee", in: squatFrames)),
            ("back_current", latestMetric(named: "Back", in: hipHingeFrames)),
            ("neck_current", latestMetric(named: "Neck", in: allFrames)),
        ])

        let repSummaries = buildRepSummaries(
            shoulderFrames: shoulderFrames,
            squatFrames: squatFrames,
            hipHingeFrames: hipHingeFrames
        )

        let mobilityIndex = average([
            normalized(romValues["right_shoulder_flexion"], upperBound: 170),
            normalized(romValues["left_shoulder_flexion"], upperBound: 170),
            normalized(romValues["right_hip_flexion"], upperBound: 120),
            normalized(romValues["left_hip_flexion"], upperBound: 120),
            normalized(romValues["right_knee_flexion"], upperBound: 130),
            normalized(romValues["left_knee_flexion"], upperBound: 130),
        ])
        let symmetryIndex = average(asymmetryScores.values.map { Optional(clamp(1 - ($0 / 100), lower: 0, upper: 1)) })
        let stabilityIndex = average([
            movementQualityScores["single_leg_balance_right"],
            movementQualityScores["single_leg_balance_left"],
            movementQualityScores["standing_front"],
        ])

        let recoveryGraphMetrics = compactMetrics([
            ("mobility_index", mobilityIndex.map { $0 * 100 }),
            ("symmetry_index", symmetryIndex.map { $0 * 100 }),
            ("stability_index", stabilityIndex.map { $0 * 100 }),
        ])

        let quickPoseResult = QuickPoseResult(
            landmarks: sampledLandmarkFrames(from: allFrames),
            jointAngles: jointAngles,
            romValues: romValues,
            asymmetryScores: asymmetryScores,
            movementQualityScores: movementQualityScores,
            gaitMetrics: nil,
            repSummaries: repSummaries,
            capturedAt: Date()
        )

        return CapturedAssessmentData(
            quickPoseResult: quickPoseResult,
            romValues: romValues,
            asymmetryScores: asymmetryScores,
            movementQualityScores: movementQualityScores,
            gaitMetrics: gaitMetrics,
            recoveryGraphMetrics: recoveryGraphMetrics
        )
        #else
        return nil
        #endif
    }

    private func buildRecoveryMap(
        romValues: [String: Double],
        asymmetryScores: [String: Double]
    ) -> RecoveryMap {
        let highlightedRegions = profile.recoverySignals.map { signal in
            let romValue = regionROMMetric(for: signal.region, romValues: romValues)
            let asymmetryValue = regionAsymmetryMetric(for: signal.region, asymmetryScores: asymmetryScores)
            let compensationHint = compensationHint(
                for: signal.region,
                romValue: romValue,
                asymmetryValue: asymmetryValue,
                severity: signal.severity
            )

            return HighlightedRegion(
                region: signal.region,
                severity: signal.severity,
                signalType: signal.type,
                romDelta: romValue,
                trend: nil,
                asymmetryFlag: (asymmetryValue ?? 0) >= 8,
                compensationHint: compensationHint
            )
        }

        return RecoveryMap(
            clientID: profile.id,
            highlightedRegions: highlightedRegions.sorted { $0.region.displayLabel < $1.region.displayLabel },
            wearableContext: WearableContext(
                hrv: profile.wearableHRV,
                strain: profile.wearableStrain,
                sleepScore: profile.wearableSleepScore,
                lastSync: profile.wearableLastSync
            ),
            priorSessions: [],
            suggestedGoal: profile.goals.first,
            generatedAt: Date()
        )
    }

    private func regionROMMetric(for region: BodyRegion, romValues: [String: Double]) -> Double? {
        switch region {
        case .rightShoulder:
            return romValues["right_shoulder_flexion"]
        case .leftShoulder:
            return romValues["left_shoulder_flexion"]
        case .rightHip:
            return romValues["right_hip_flexion"]
        case .leftHip:
            return romValues["left_hip_flexion"]
        case .rightKnee:
            return romValues["right_knee_flexion"]
        case .leftKnee:
            return romValues["left_knee_flexion"]
        case .lowerBack, .upperBack:
            return romValues["back_flexion"]
        case .neck:
            return romValues["neck_flexion"]
        default:
            return nil
        }
    }

    private func regionAsymmetryMetric(for region: BodyRegion, asymmetryScores: [String: Double]) -> Double? {
        switch region {
        case .rightShoulder, .leftShoulder:
            return asymmetryScores["shoulder_flexion"]
        case .rightHip, .leftHip:
            return asymmetryScores["hip_flexion"]
        case .rightKnee, .leftKnee:
            return asymmetryScores["knee_flexion"]
        default:
            return asymmetryScores["single_leg_balance"]
        }
    }

    private func compensationHint(
        for region: BodyRegion,
        romValue: Double?,
        asymmetryValue: Double?,
        severity: Int
    ) -> String? {
        if let asymmetryValue, asymmetryValue >= 12 {
            return "Move through this pattern slowly and keep both sides as even as you comfortably can."
        }

        if let romValue, romValue < 80 {
            return "Stay in your available range here and avoid forcing extra depth."
        }

        if severity >= 7 {
            return "Use a calm tempo through \(region.displayLabel.lowercased()) and focus on control over speed."
        }

        return nil
    }

    private func filteredMetrics(
        for artifact: QuickPoseVerificationFrameArtifact,
        step: CaptureStep
    ) -> [QuickPoseVerificationMetric] {
        let orderedNames: [String]

        switch step {
        case .standingFront:
            orderedNames = ["Right Shoulder", "Left Shoulder", "Shoulder ROM Asymmetry", "Right Hip", "Left Hip"]
        case .standingSide:
            orderedNames = ["Right Hip", "Left Hip", "Back", "Neck"]
        case .shoulderFlexion:
            orderedNames = ["Right Shoulder", "Left Shoulder", "Shoulder ROM Asymmetry"]
        case .squat:
            orderedNames = ["Right Knee", "Left Knee", "Right Hip", "Left Hip"]
        case .hipHinge:
            orderedNames = ["Right Hip", "Left Hip", "Back"]
        case .singleLegBalanceRight, .singleLegBalanceLeft:
            orderedNames = ["Right Hip", "Left Hip", "Neck"]
        }

        let metricsByName = Dictionary(uniqueKeysWithValues: artifact.metrics.map { ($0.name, $0) })
        return orderedNames.compactMap { metricsByName[$0] }
    }

    private func estimatedRepCount(for step: CaptureStep) -> Int {
        #if canImport(QuickPoseCore)
        let frames = capturedFramesByStep[step, default: []]

        switch step {
        case .shoulderFlexion:
            return estimatedRepCount(metricName: "Right Shoulder", in: frames)
        case .squat:
            return estimatedRepCount(metricName: "Right Knee", in: frames)
        case .hipHinge:
            return estimatedRepCount(metricName: "Right Hip", in: frames)
        default:
            return 0
        }
        #else
        return 0
        #endif
    }

    #if canImport(QuickPoseCore)
    private func makeCapturedFrame(
        artifact: QuickPoseVerificationFrameArtifact,
        landmarks: QuickPose.Landmarks?
    ) -> CapturedPoseFrame {
        func pointSample(_ point: QuickPose.Point3d) -> PosePointSample {
            PosePointSample(
                x: point.x,
                y: point.y,
                z: point.z,
                visibility: point.visibility,
                presence: point.presence
            )
        }

        guard let landmarks else {
            return CapturedPoseFrame(
                artifact: artifact,
                shoulderMid: nil,
                hipMid: nil,
                leftShoulder: nil,
                rightShoulder: nil,
                leftHip: nil,
                rightHip: nil,
                leftAnkle: nil,
                rightAnkle: nil
            )
        }

        return CapturedPoseFrame(
            artifact: artifact,
            shoulderMid: pointSample(landmarks.landmark(forBody: .shoulderMid)),
            hipMid: pointSample(landmarks.landmark(forBody: .hipMid)),
            leftShoulder: pointSample(landmarks.landmark(forBody: .shoulder(side: .left))),
            rightShoulder: pointSample(landmarks.landmark(forBody: .shoulder(side: .right))),
            leftHip: pointSample(landmarks.landmark(forBody: .hip(side: .left))),
            rightHip: pointSample(landmarks.landmark(forBody: .hip(side: .right))),
            leftAnkle: pointSample(landmarks.landmark(forBody: .ankle(side: .left))),
            rightAnkle: pointSample(landmarks.landmark(forBody: .ankle(side: .right)))
        )
    }

    private func successfulFrames(for steps: [CaptureStep]) -> [CapturedPoseFrame] {
        steps.flatMap { capturedFramesByStep[$0, default: []] }
            .filter { $0.artifact.status == "success" }
    }

    private func sampledLandmarkFrames(from frames: [CapturedPoseFrame]) -> [LandmarkFrame] {
        let landmarkFrames = frames.filter { !$0.artifact.bodyLandmarks.isEmpty }
        guard !landmarkFrames.isEmpty else { return [] }

        let targetCount = min(28, landmarkFrames.count)
        let denominator = max(targetCount - 1, 1)
        let step = Double(max(landmarkFrames.count - 1, 1)) / Double(denominator)
        let selectedIndices = Set((0..<targetCount).map { index in
            Int(round(Double(index) * step))
        } + [landmarkFrames.count - 1])

        let startDate = captureStartedAt ?? Date()
        let firstFrameTime = landmarkFrames.first?.artifact.timeSeconds ?? 0

        return selectedIndices.sorted().map { index in
            let frame = landmarkFrames[index]
            return LandmarkFrame(
                capturedAt: startDate.addingTimeInterval(max(0, frame.artifact.timeSeconds - firstFrameTime)),
                landmarks: frame.artifact.bodyLandmarks.enumerated().map { landmarkIndex, point in
                    Landmark(
                        index: landmarkIndex,
                        x: point.x,
                        y: point.y,
                        z: point.z,
                        visibility: point.visibility
                    )
                }
            )
        }
    }

    private func maxMetric(named name: String, in frames: [CapturedPoseFrame]) -> Double? {
        metricSeries(named: name, in: frames).max()
    }

    private func latestMetric(named name: String, in frames: [CapturedPoseFrame]) -> Double? {
        frames.reversed().compactMap { frame in
            frame.artifact.metrics.first(where: { $0.name == name })?.value
        }.first
    }

    private func metricSeries(named name: String, in frames: [CapturedPoseFrame]) -> [Double] {
        frames.compactMap { frame in
            frame.artifact.metrics.first(where: { $0.name == name })?.value
        }
    }

    private func estimatedRepCount(metricName: String, in frames: [CapturedPoseFrame]) -> Int {
        let samples = metricSeries(named: metricName, in: frames)
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
        var aboveHighThreshold = false

        for sample in samples {
            if !aboveHighThreshold, sample >= highThreshold {
                aboveHighThreshold = true
            } else if aboveHighThreshold, sample <= lowThreshold {
                count += 1
                aboveHighThreshold = false
            }
        }

        return count
    }

    private func asymmetryPercentage(right: Double?, left: Double?) -> Double? {
        guard let right, let left else { return nil }
        let dominant = max(abs(right), abs(left), 1)
        return abs(right - left) / dominant * 100
    }

    private func shoulderFlexionQuality(for frames: [CapturedPoseFrame]) -> Double? {
        let rightShoulder = maxMetric(named: "Right Shoulder", in: frames)
        let leftShoulder = maxMetric(named: "Left Shoulder", in: frames)
        let asymmetry = asymmetryPercentage(right: rightShoulder, left: leftShoulder)

        return average([
            normalized(average([rightShoulder, leftShoulder]), upperBound: 170),
            asymmetry.map { clamp(1 - ($0 / 100), lower: 0, upper: 1) }
        ])
    }

    private func squatQuality(for frames: [CapturedPoseFrame]) -> Double? {
        let repScore = normalized(Double(estimatedRepCount(metricName: "Right Knee", in: frames)), upperBound: 3)
        return average([
            normalized(average([
                maxMetric(named: "Right Knee", in: frames),
                maxMetric(named: "Left Knee", in: frames),
            ]), upperBound: 125),
            normalized(average([
                maxMetric(named: "Right Hip", in: frames),
                maxMetric(named: "Left Hip", in: frames),
            ]), upperBound: 115),
            repScore,
        ])
    }

    private func hipHingeQuality(for frames: [CapturedPoseFrame]) -> Double? {
        average([
            normalized(average([
                maxMetric(named: "Right Hip", in: frames),
                maxMetric(named: "Left Hip", in: frames),
            ]), upperBound: 110),
            normalized(maxMetric(named: "Back", in: frames), upperBound: 70),
        ])
    }

    private func standingQuality(for frames: [CapturedPoseFrame]) -> Double? {
        average([
            postureSymmetryScore(for: frames),
            stabilityScore(for: frames),
        ])
    }

    private func stabilityScore(for frames: [CapturedPoseFrame]) -> Double? {
        guard let sway = normalizedSway(for: frames) else { return nil }
        return clamp(1 - min(1, sway * 2.5), lower: 0, upper: 1)
    }

    private func normalizedSway(for frames: [CapturedPoseFrame]) -> Double? {
        let midPoints = frames.compactMap { $0.hipMid ?? $0.shoulderMid }
        guard midPoints.count >= 3 else { return nil }

        let centerX = midPoints.map(\.x).average
        let centerY = midPoints.map(\.y).average
        let averageDistance = midPoints
            .map { hypot($0.x - centerX, $0.y - centerY) }
            .average

        let bodyScale = frames.compactMap { frame -> Double? in
            if let leftShoulder = frame.leftShoulder, let rightShoulder = frame.rightShoulder {
                return leftShoulder.distance(to: rightShoulder)
            }

            if let leftHip = frame.leftHip, let rightHip = frame.rightHip {
                return leftHip.distance(to: rightHip)
            }

            return nil
        }.averageOptional

        guard let bodyScale, bodyScale > 0 else { return nil }
        return averageDistance / bodyScale
    }

    private func postureSymmetryScore(for frames: [CapturedPoseFrame]) -> Double? {
        let misalignmentValues = frames.compactMap { frame -> Double? in
            guard
                let leftShoulder = frame.leftShoulder,
                let rightShoulder = frame.rightShoulder,
                let leftHip = frame.leftHip,
                let rightHip = frame.rightHip
            else {
                return nil
            }

            let shoulderWidth = max(leftShoulder.distance(to: rightShoulder), 0.01)
            let hipWidth = max(leftHip.distance(to: rightHip), 0.01)
            let shoulderLevelDiff = abs(leftShoulder.y - rightShoulder.y) / shoulderWidth
            let hipLevelDiff = abs(leftHip.y - rightHip.y) / hipWidth

            return (shoulderLevelDiff + hipLevelDiff) / 2
        }

        guard let averageMisalignment = misalignmentValues.averageOptional else { return nil }
        return clamp(1 - min(1, averageMisalignment * 3), lower: 0, upper: 1)
    }

    private func buildRepSummaries(
        shoulderFrames: [CapturedPoseFrame],
        squatFrames: [CapturedPoseFrame],
        hipHingeFrames: [CapturedPoseFrame]
    ) -> [RepSummary] {
        var summaries: [RepSummary] = []

        let shoulderCount = estimatedRepCount(metricName: "Right Shoulder", in: shoulderFrames)
        if shoulderCount > 0 {
            summaries.append(
                RepSummary(
                    movement: "shoulder_flexion",
                    count: shoulderCount,
                    peakAngles: compactMetrics([
                        ("right_shoulder", maxMetric(named: "Right Shoulder", in: shoulderFrames)),
                        ("left_shoulder", maxMetric(named: "Left Shoulder", in: shoulderFrames)),
                    ]),
                    troughAngles: compactMetrics([
                        ("right_shoulder", metricSeries(named: "Right Shoulder", in: shoulderFrames).min()),
                        ("left_shoulder", metricSeries(named: "Left Shoulder", in: shoulderFrames).min()),
                    ])
                )
            )
        }

        let squatCount = estimatedRepCount(metricName: "Right Knee", in: squatFrames)
        if squatCount > 0 {
            summaries.append(
                RepSummary(
                    movement: "squat",
                    count: squatCount,
                    peakAngles: compactMetrics([
                        ("right_knee", maxMetric(named: "Right Knee", in: squatFrames)),
                        ("left_knee", maxMetric(named: "Left Knee", in: squatFrames)),
                    ]),
                    troughAngles: compactMetrics([
                        ("right_knee", metricSeries(named: "Right Knee", in: squatFrames).min()),
                        ("left_knee", metricSeries(named: "Left Knee", in: squatFrames).min()),
                    ])
                )
            )
        }

        let hingeCount = estimatedRepCount(metricName: "Right Hip", in: hipHingeFrames)
        if hingeCount > 0 {
            summaries.append(
                RepSummary(
                    movement: "hip_hinge",
                    count: hingeCount,
                    peakAngles: compactMetrics([
                        ("right_hip", maxMetric(named: "Right Hip", in: hipHingeFrames)),
                        ("left_hip", maxMetric(named: "Left Hip", in: hipHingeFrames)),
                    ]),
                    troughAngles: compactMetrics([
                        ("right_hip", metricSeries(named: "Right Hip", in: hipHingeFrames).min()),
                        ("left_hip", metricSeries(named: "Left Hip", in: hipHingeFrames).min()),
                    ])
                )
            )
        }

        return summaries
    }
    #endif

    private func compactMetrics(_ pairs: [(String, Double?)]) -> [String: Double] {
        var result: [String: Double] = [:]

        for (key, value) in pairs {
            if let value {
                result[key] = value
            }
        }

        return result
    }

    private func normalized(_ value: Double?, upperBound: Double) -> Double? {
        guard let value, upperBound > 0 else { return nil }
        return clamp(value / upperBound, lower: 0, upper: 1)
    }

    private func average(_ values: [Double?]) -> Double? {
        let resolvedValues = values.compactMap { $0 }
        guard !resolvedValues.isEmpty else { return nil }
        return resolvedValues.average
    }

    private func clamp(_ value: Double, lower: Double = 0, upper: Double = 1) -> Double {
        min(max(value, lower), upper)
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    var averageOptional: Double? {
        isEmpty ? nil : average
    }
}
