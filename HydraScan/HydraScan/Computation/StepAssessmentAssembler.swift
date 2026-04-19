import Foundation

#if canImport(QuickPoseCore)
import QuickPoseCore
#endif

struct PosePointSample {
    let x: Double
    let y: Double
    let z: Double
    let visibility: Double
    let presence: Double

    func distance(to other: PosePointSample) -> Double {
        hypot(x - other.x, y - other.y)
    }

    static func angleDegrees(a: PosePointSample, b: PosePointSample, c: PosePointSample) -> Double {
        let ba = SIMD3<Double>(a.x - b.x, a.y - b.y, a.z - b.z)
        let bc = SIMD3<Double>(c.x - b.x, c.y - b.y, c.z - b.z)
        return ba.angleDegrees(to: bc)
    }
}

struct CapturedPoseFrame {
    let artifact: QuickPoseVerificationFrameArtifact
    let nose: PosePointSample?
    let leftEar: PosePointSample?
    let rightEar: PosePointSample?
    let shoulderMid: PosePointSample?
    let hipMid: PosePointSample?
    let leftShoulder: PosePointSample?
    let rightShoulder: PosePointSample?
    let leftElbow: PosePointSample?
    let rightElbow: PosePointSample?
    let leftWrist: PosePointSample?
    let rightWrist: PosePointSample?
    let leftHip: PosePointSample?
    let rightHip: PosePointSample?
    let leftKnee: PosePointSample?
    let rightKnee: PosePointSample?
    let leftAnkle: PosePointSample?
    let rightAnkle: PosePointSample?

    var isSuccessful: Bool {
        artifact.status == "success"
    }

    var preferredEar: PosePointSample? {
        rightEar ?? leftEar
    }

    var kneeMid: PosePointSample? {
        midpoint(leftKnee, rightKnee)
    }

    private func midpoint(_ lhs: PosePointSample?, _ rhs: PosePointSample?) -> PosePointSample? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return PosePointSample(
                x: (lhs.x + rhs.x) / 2,
                y: (lhs.y + rhs.y) / 2,
                z: (lhs.z + rhs.z) / 2,
                visibility: min(lhs.visibility, rhs.visibility),
                presence: min(lhs.presence, rhs.presence)
            )
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }
}

struct StepAssessmentAssembler {
    let captureStartedAt: Date

    func buildStepResult(
        step: CaptureStep,
        frames: [CapturedPoseFrame]
    ) -> QuickPoseStepResult? {
        guard let firstFrame = frames.first, let lastFrame = frames.last else { return nil }

        let successfulFrames = frames.filter(\.isSuccessful)
        var payload = StepMetricPayload()

        switch step {
        case .standingFront:
            payload.merge(PostureMetricsCalculator.standingFront(frames: successfulFrames))
        case .standingSide:
            payload.merge(PostureMetricsCalculator.standingSide(frames: successfulFrames))
        case .shoulderFlexion:
            payload.merge(shoulderFlexionPayload(frames: successfulFrames))
        case .squat:
            payload.merge(SquatMetricsCalculator.evaluate(frames: successfulFrames))
        case .hipHinge:
            payload.merge(HipHingeMetricsCalculator.evaluate(frames: successfulFrames))
        case .singleLegBalanceRight:
            #if canImport(QuickPoseCore)
            payload.merge(BalanceMetricsCalculator.evaluate(frames: successfulFrames, side: .right))
            #endif
        case .singleLegBalanceLeft:
            #if canImport(QuickPoseCore)
            payload.merge(BalanceMetricsCalculator.evaluate(frames: successfulFrames, side: .left))
            #endif
        }

        let startedAt = captureStartedAt.addingTimeInterval(firstFrame.artifact.timeSeconds)
        let completedAt = captureStartedAt.addingTimeInterval(lastFrame.artifact.timeSeconds)
        let confidence = frames.isEmpty ? 0 : Double(successfulFrames.count) / Double(frames.count)
        let completenessStatus = completenessStatus(
            for: step,
            payload: payload,
            confidence: confidence,
            successfulFrameCount: successfulFrames.count
        )
        let source = computationSource(for: payload)
        let missingMetricKeys = missingMetricKeys(for: step, payload: payload)

        return QuickPoseStepResult(
            step: step,
            startedAt: startedAt,
            completedAt: completedAt,
            confidence: confidence,
            landmarks: sampledLandmarkFrames(from: successfulFrames, startDate: captureStartedAt),
            jointAngles: payload.jointAngles,
            romValues: payload.romValues,
            asymmetryScores: payload.asymmetryScores,
            movementQualityScores: payload.movementQualityScores,
            gaitMetrics: payload.gaitMetrics,
            repSummaries: payload.repSummaries,
            derivedMetrics: payload.derivedMetrics,
            computationSource: source,
            completenessStatus: completenessStatus,
            missingMetricKeys: missingMetricKeys
        )
    }

    func buildAssessmentData(
        orderedSteps: [CaptureStepDefinition],
        framesByStep: [CaptureStep: [CapturedPoseFrame]]
    ) -> (quickPoseResult: QuickPoseResult, romValues: [String: Double], asymmetryScores: [String: Double], movementQualityScores: [String: Double], gaitMetrics: [String: Double], recoveryGraphMetrics: [String: Double])? {
        let allFrames = orderedSteps.flatMap { framesByStep[$0.step, default: []] }
        guard !allFrames.isEmpty else { return nil }

        let stepResults = orderedSteps.compactMap { definition in
            buildStepResult(step: definition.step, frames: framesByStep[definition.step, default: []])
        }
        guard !stepResults.isEmpty else { return nil }

        let stepPayload = synthesizeAggregatePayload(from: stepResults)

        let mobilityIndex = ScanMath.average([
            ScanMath.normalized(stepPayload.romValues[ScanMetricCatalog.ROM.rightShoulderFlexion], upperBound: 170),
            ScanMath.normalized(stepPayload.romValues[ScanMetricCatalog.ROM.leftShoulderFlexion], upperBound: 170),
            ScanMath.normalized(stepPayload.romValues[ScanMetricCatalog.ROM.rightHipFlexion], upperBound: 120),
            ScanMath.normalized(stepPayload.romValues[ScanMetricCatalog.ROM.leftHipFlexion], upperBound: 120),
            ScanMath.normalized(stepPayload.romValues[ScanMetricCatalog.ROM.rightKneeFlexion], upperBound: 130),
            ScanMath.normalized(stepPayload.romValues[ScanMetricCatalog.ROM.leftKneeFlexion], upperBound: 130),
            ScanMath.normalized(stepPayload.romValues[ScanMetricCatalog.ROM.rightAnkleDorsiflexion], upperBound: 45),
            ScanMath.normalized(stepPayload.romValues[ScanMetricCatalog.ROM.leftAnkleDorsiflexion], upperBound: 45),
        ])
        let symmetryIndex = ScanMath.average(stepPayload.asymmetryScores.values.map {
            AsymmetryCalculator.normalizedSymmetryScore(asymmetry: $0)
        })
        let stabilityIndex = ScanMath.average([
            stepPayload.movementQualityScores[ScanMetricCatalog.MovementQuality.standingFront],
            stepPayload.movementQualityScores[ScanMetricCatalog.MovementQuality.standingSide],
            stepPayload.movementQualityScores[ScanMetricCatalog.MovementQuality.singleLegBalanceRight],
            stepPayload.movementQualityScores[ScanMetricCatalog.MovementQuality.singleLegBalanceLeft],
        ])

        let recoveryGraphMetrics = compactMetrics([
            ("mobility_index", mobilityIndex.map { $0 * 100 }),
            ("symmetry_index", symmetryIndex.map { $0 * 100 }),
            ("stability_index", stabilityIndex.map { $0 * 100 }),
        ])

        let quickPoseResult = QuickPoseResult(
            schemaVersion: ScanMetricCatalog.schemaVersion,
            stepResults: stepResults,
            landmarks: stepResults.flatMap(\.landmarks),
            jointAngles: stepPayload.jointAngles,
            romValues: stepPayload.romValues,
            asymmetryScores: stepPayload.asymmetryScores,
            movementQualityScores: stepPayload.movementQualityScores,
            gaitMetrics: stepPayload.gaitMetrics,
            repSummaries: stepPayload.repSummaries,
            capturedAt: stepResults.last?.completedAt ?? Date()
        )

        return (
            quickPoseResult: quickPoseResult,
            romValues: stepPayload.romValues,
            asymmetryScores: stepPayload.asymmetryScores,
            movementQualityScores: stepPayload.movementQualityScores,
            gaitMetrics: stepPayload.gaitMetrics,
            recoveryGraphMetrics: recoveryGraphMetrics
        )
    }

    private func shoulderFlexionPayload(frames: [CapturedPoseFrame]) -> StepMetricPayload {
        var payload = StepMetricPayload()
        let rightSeries = ScanMetricResolver.series(for: .rightShoulderFlexion, in: frames)
        let leftSeries = ScanMetricResolver.series(for: .leftShoulderFlexion, in: frames)
        let rightShoulder = rightSeries.maxValue
        let leftShoulder = leftSeries.maxValue
        let asymmetry = AsymmetryCalculator.percentage(right: rightShoulder, left: leftShoulder)
        let quality = ScanMath.average([
            ScanMath.normalized(ScanMath.average([rightShoulder, leftShoulder]), upperBound: 170),
            AsymmetryCalculator.normalizedSymmetryScore(asymmetry: asymmetry),
        ])

        payload.note(source: rightSeries.source)
        payload.note(source: leftSeries.source)

        payload.romValues = compactMetrics([
            (ScanMetricCatalog.ROM.rightShoulderFlexion, rightShoulder),
            (ScanMetricCatalog.ROM.leftShoulderFlexion, leftShoulder),
        ])
        payload.asymmetryScores = compactMetrics([
            (ScanMetricCatalog.Asymmetry.shoulderFlexion, asymmetry),
        ])
        payload.movementQualityScores = compactMetrics([
            (ScanMetricCatalog.MovementQuality.shoulderFlexion, quality),
        ])
        payload.jointAngles = compactMetrics([
            ("right_shoulder_current", rightSeries.latestValue),
            ("left_shoulder_current", leftSeries.latestValue),
        ])

        let repCount = rightSeries.estimatedRepCount
        if repCount > 0 {
            payload.repSummaries = [
                RepSummary(
                    movement: ScanMetricCatalog.MovementQuality.shoulderFlexion,
                    count: repCount,
                    peakAngles: compactMetrics([
                        ("right_shoulder", rightShoulder),
                        ("left_shoulder", leftShoulder),
                    ]),
                    troughAngles: compactMetrics([
                        ("right_shoulder", rightSeries.minValue),
                        ("left_shoulder", leftSeries.minValue),
                    ])
                )
            ]
        }

        return payload
    }

    private func synthesizeAggregatePayload(from stepResults: [QuickPoseStepResult]) -> StepMetricPayload {
        var payload = StepMetricPayload()

        for stepResult in stepResults {
            payload.jointAngles.merge(stepResult.jointAngles) { _, new in new }
            payload.repSummaries.append(contentsOf: stepResult.repSummaries)
            payload.computationSources.insert(stepResult.computationSource)

            for (key, value) in stepResult.romValues {
                payload.romValues[key] = max(payload.romValues[key] ?? value, value)
            }

            for (key, value) in stepResult.asymmetryScores {
                payload.asymmetryScores[key] = max(payload.asymmetryScores[key] ?? value, value)
            }

            for (key, value) in stepResult.movementQualityScores {
                payload.movementQualityScores[key] = value
            }

            for (key, value) in stepResult.gaitMetrics {
                payload.gaitMetrics[key] = value
            }

            for (key, value) in stepResult.derivedMetrics {
                payload.derivedMetrics[key] = value
            }
        }

        let rightBalanceStability = stepResults
            .first(where: { $0.step == .singleLegBalanceRight })?
            .derivedMetrics[ScanMetricCatalog.Derived.stabilityScore]
        let leftBalanceStability = stepResults
            .first(where: { $0.step == .singleLegBalanceLeft })?
            .derivedMetrics[ScanMetricCatalog.Derived.stabilityScore]

        if let balanceAsymmetry = AsymmetryCalculator.percentage(
            right: rightBalanceStability.map { $0 * 100 },
            left: leftBalanceStability.map { $0 * 100 }
        ) {
            payload.asymmetryScores[ScanMetricCatalog.Asymmetry.singleLegBalance] = balanceAsymmetry
        }

        return payload
    }

    private func computationSource(for payload: StepMetricPayload) -> QuickPoseComputationSource {
        if payload.computationSources.count > 1 {
            return .mixed
        }

        return payload.computationSources.first ?? .landmarkFallback
    }

    private func completenessStatus(
        for step: CaptureStep,
        payload: StepMetricPayload,
        confidence: Double,
        successfulFrameCount: Int
    ) -> QuickPoseStepCompletenessStatus {
        let missing = missingMetricKeys(for: step, payload: payload)
        let presentMetricCount = payload.derivedMetrics.count +
            payload.romValues.count +
            payload.asymmetryScores.count +
            payload.movementQualityScores.count +
            payload.gaitMetrics.count

        if successfulFrameCount == 0 || confidence < 0.3 || presentMetricCount == 0 {
            return .insufficientSignal
        }

        if missing.isEmpty {
            return .complete
        }

        if presentMetricCount <= 1 {
            return .insufficientSignal
        }

        return .partial
    }

    private func missingMetricKeys(for step: CaptureStep, payload: StepMetricPayload) -> [String] {
        let required = requiredMetricKeys(for: step)
        let available = Set(payload.derivedMetrics.keys)
            .union(payload.romValues.keys)
            .union(payload.asymmetryScores.keys)
            .union(payload.movementQualityScores.keys)
            .union(payload.gaitMetrics.keys)

        return required.filter { !available.contains($0) }
    }

    private func requiredMetricKeys(for step: CaptureStep) -> [String] {
        switch step {
        case .standingFront:
            return [
                ScanMetricCatalog.Derived.shoulderLevelOffset,
                ScanMetricCatalog.Derived.hipLevelOffset,
                ScanMetricCatalog.Derived.kneeAlignmentOffset,
                ScanMetricCatalog.Derived.frontalPostureScore,
                ScanMetricCatalog.MovementQuality.standingFront,
            ]
        case .standingSide:
            return [
                ScanMetricCatalog.Derived.forwardHeadOffset,
                ScanMetricCatalog.Derived.thoracicCurveScore,
                ScanMetricCatalog.Derived.lumbarCurveScore,
                ScanMetricCatalog.Derived.trunkAlignmentScore,
                ScanMetricCatalog.MovementQuality.standingSide,
            ]
        case .shoulderFlexion:
            return [
                ScanMetricCatalog.ROM.rightShoulderFlexion,
                ScanMetricCatalog.ROM.leftShoulderFlexion,
                ScanMetricCatalog.Asymmetry.shoulderFlexion,
                ScanMetricCatalog.MovementQuality.shoulderFlexion,
            ]
        case .squat:
            return [
                ScanMetricCatalog.ROM.rightHipFlexion,
                ScanMetricCatalog.ROM.leftHipFlexion,
                ScanMetricCatalog.ROM.rightKneeFlexion,
                ScanMetricCatalog.ROM.leftKneeFlexion,
                ScanMetricCatalog.ROM.rightAnkleDorsiflexion,
                ScanMetricCatalog.ROM.leftAnkleDorsiflexion,
                ScanMetricCatalog.Asymmetry.kneeFlexion,
                ScanMetricCatalog.Asymmetry.ankleDorsiflexion,
                ScanMetricCatalog.MovementQuality.squat,
                ScanMetricCatalog.Derived.squatDepth,
                ScanMetricCatalog.Derived.kneeTrackingLeft,
                ScanMetricCatalog.Derived.kneeTrackingRight,
                ScanMetricCatalog.Derived.trunkLean,
                ScanMetricCatalog.Derived.ankleMobilityLeft,
                ScanMetricCatalog.Derived.ankleMobilityRight,
            ]
        case .hipHinge:
            return [
                ScanMetricCatalog.ROM.rightHipFlexion,
                ScanMetricCatalog.ROM.leftHipFlexion,
                ScanMetricCatalog.ROM.spinalFlexion,
                ScanMetricCatalog.Asymmetry.hipFlexion,
                ScanMetricCatalog.MovementQuality.hipHinge,
                ScanMetricCatalog.Derived.hipROMRight,
                ScanMetricCatalog.Derived.hipROMLeft,
                ScanMetricCatalog.Derived.lumbarFlexion,
                ScanMetricCatalog.Derived.hamstringFlexibilityRight,
                ScanMetricCatalog.Derived.hamstringFlexibilityLeft,
            ]
        case .singleLegBalanceRight:
            return [
                ScanMetricCatalog.MovementQuality.singleLegBalanceRight,
                ScanMetricCatalog.Gait.rightBalanceSway,
                ScanMetricCatalog.Gait.rightAnkleWobble,
                ScanMetricCatalog.Derived.stabilityScore,
                ScanMetricCatalog.Derived.ankleWobble,
                ScanMetricCatalog.Derived.compensationScore,
                ScanMetricCatalog.Derived.swayDistance,
            ]
        case .singleLegBalanceLeft:
            return [
                ScanMetricCatalog.MovementQuality.singleLegBalanceLeft,
                ScanMetricCatalog.Gait.leftBalanceSway,
                ScanMetricCatalog.Gait.leftAnkleWobble,
                ScanMetricCatalog.Derived.stabilityScore,
                ScanMetricCatalog.Derived.ankleWobble,
                ScanMetricCatalog.Derived.compensationScore,
                ScanMetricCatalog.Derived.swayDistance,
            ]
        }
    }

    private func sampledLandmarkFrames(from frames: [CapturedPoseFrame], startDate: Date) -> [LandmarkFrame] {
        let landmarkFrames = frames.filter { !$0.artifact.bodyLandmarks.isEmpty }
        guard !landmarkFrames.isEmpty else { return [] }

        let targetCount = min(8, landmarkFrames.count)
        let denominator = max(targetCount - 1, 1)
        let step = Double(max(landmarkFrames.count - 1, 1)) / Double(denominator)
        let selectedIndices = Set((0..<targetCount).map { index in
            Int(round(Double(index) * step))
        } + [landmarkFrames.count - 1])

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
}
