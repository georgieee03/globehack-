import Foundation

#if canImport(QuickPoseCore)
import QuickPoseCore
#endif

enum BalanceMetricsCalculator {
    static func evaluate(frames: [CapturedPoseFrame], side: QuickPose.Side) -> StepMetricPayload {
        let successfulFrames = frames.filter(\.isSuccessful)
        var payload = StepMetricPayload()
        payload.note(source: .landmarkFallback)

        let sway = normalizedSway(for: successfulFrames)
        let ankleWobble = ankleWobble(for: successfulFrames, side: side)
        let compensation = compensationScore(for: successfulFrames, side: side)
        let stability = ScanMath.average([
            sway.map { ScanMath.clamp(1 - min(1, $0 * 2.5)) },
            ankleWobble.map { ScanMath.clamp(1 - ($0 / 18)) },
            compensation,
        ])

        let stepKey = side == .right
            ? ScanMetricCatalog.MovementQuality.singleLegBalanceRight
            : ScanMetricCatalog.MovementQuality.singleLegBalanceLeft
        let swayKey = side == .right
            ? ScanMetricCatalog.Gait.rightBalanceSway
            : ScanMetricCatalog.Gait.leftBalanceSway
        let wobbleKey = side == .right
            ? ScanMetricCatalog.Gait.rightAnkleWobble
            : ScanMetricCatalog.Gait.leftAnkleWobble

        payload.movementQualityScores = compactMetrics([
            (stepKey, stability),
        ])
        payload.gaitMetrics = compactMetrics([
            (swayKey, sway.map { $0 * 100 }),
            (wobbleKey, ankleWobble),
        ])
        payload.derivedMetrics = compactMetrics([
            (ScanMetricCatalog.Derived.stabilityScore, stability),
            (ScanMetricCatalog.Derived.ankleWobble, ankleWobble),
            (ScanMetricCatalog.Derived.compensationScore, compensation),
            (ScanMetricCatalog.Derived.swayDistance, sway.map { $0 * 100 }),
        ])
        return payload
    }

    private static func normalizedSway(for frames: [CapturedPoseFrame]) -> Double? {
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

    private static func ankleWobble(for frames: [CapturedPoseFrame], side: QuickPose.Side) -> Double? {
        let ankleSamples = frames.compactMap { frame -> PosePointSample? in
            switch side {
            case .left:
                return frame.leftAnkle
            case .right:
                return frame.rightAnkle
            }
        }

        guard ankleSamples.count >= 3 else { return nil }
        let xs = ankleSamples.map(\.x)
        let ys = ankleSamples.map(\.y)
        guard
            let xDeviation = ScanMath.standardDeviation(xs),
            let yDeviation = ScanMath.standardDeviation(ys)
        else {
            return nil
        }

        let averageScale = frames.compactMap { frame -> Double? in
            switch side {
            case .left:
                guard let knee = frame.leftKnee, let ankle = frame.leftAnkle else { return nil }
                return knee.distance(to: ankle)
            case .right:
                guard let knee = frame.rightKnee, let ankle = frame.rightAnkle else { return nil }
                return knee.distance(to: ankle)
            }
        }.averageOptional

        guard let averageScale, averageScale > 0 else { return nil }
        return hypot(xDeviation, yDeviation) / averageScale * 100
    }

    private static func compensationScore(for frames: [CapturedPoseFrame], side: QuickPose.Side) -> Double? {
        let torsoOffsets = frames.compactMap { frame -> Double? in
            guard let shoulderMid = frame.shoulderMid, let hipMid = frame.hipMid else { return nil }
            let torsoHeight = max(abs(shoulderMid.y - hipMid.y), 0.01)
            return abs(shoulderMid.x - hipMid.x) / torsoHeight
        }

        let hipDrop = frames.compactMap { frame -> Double? in
            switch side {
            case .left:
                guard let leftHip = frame.leftHip, let rightHip = frame.rightHip else { return nil }
                return abs(leftHip.y - rightHip.y)
            case .right:
                guard let leftHip = frame.leftHip, let rightHip = frame.rightHip else { return nil }
                return abs(leftHip.y - rightHip.y)
            }
        }

        return ScanMath.average([
            torsoOffsets.averageOptional.map { ScanMath.clamp(1 - ($0 * 2.5)) },
            hipDrop.averageOptional.map { ScanMath.clamp(1 - ($0 * 10)) },
        ])
    }
}
