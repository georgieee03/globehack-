import Foundation

enum PostureMetricsCalculator {
    static func standingFront(frames: [CapturedPoseFrame]) -> StepMetricPayload {
        let successfulFrames = frames.filter(\.isSuccessful)
        var payload = StepMetricPayload()
        payload.note(source: .landmarkFallback)

        let shoulderOffsets = successfulFrames.compactMap { frame -> Double? in
            guard
                let leftShoulder = frame.leftShoulder,
                let rightShoulder = frame.rightShoulder
            else { return nil }

            let width = max(leftShoulder.distance(to: rightShoulder), 0.01)
            return abs(leftShoulder.y - rightShoulder.y) / width * 100
        }

        let hipOffsets = successfulFrames.compactMap { frame -> Double? in
            guard
                let leftHip = frame.leftHip,
                let rightHip = frame.rightHip
            else { return nil }

            let width = max(leftHip.distance(to: rightHip), 0.01)
            return abs(leftHip.y - rightHip.y) / width * 100
        }

        let kneeOffsets = successfulFrames.compactMap { frame -> Double? in
            guard
                let leftKnee = frame.leftKnee,
                let rightKnee = frame.rightKnee,
                let leftAnkle = frame.leftAnkle,
                let rightAnkle = frame.rightAnkle
            else { return nil }

            let leftTracking = abs(leftKnee.x - leftAnkle.x)
            let rightTracking = abs(rightKnee.x - rightAnkle.x)
            let scale = max(leftAnkle.distance(to: rightAnkle), 0.01)
            return abs(leftTracking - rightTracking) / scale * 100
        }

        let postureScore = ScanMath.average([
            shoulderOffsets.averageOptional.map { ScanMath.clamp(1 - ($0 / 18)) },
            hipOffsets.averageOptional.map { ScanMath.clamp(1 - ($0 / 18)) },
            kneeOffsets.averageOptional.map { ScanMath.clamp(1 - ($0 / 22)) },
        ])

        payload.derivedMetrics = compactMetrics([
            (ScanMetricCatalog.Derived.shoulderLevelOffset, shoulderOffsets.averageOptional),
            (ScanMetricCatalog.Derived.hipLevelOffset, hipOffsets.averageOptional),
            (ScanMetricCatalog.Derived.kneeAlignmentOffset, kneeOffsets.averageOptional),
            (ScanMetricCatalog.Derived.frontalPostureScore, postureScore),
        ])
        payload.movementQualityScores = compactMetrics([
            (ScanMetricCatalog.MovementQuality.standingFront, postureScore),
        ])
        return payload
    }

    static func standingSide(frames: [CapturedPoseFrame]) -> StepMetricPayload {
        let successfulFrames = frames.filter(\.isSuccessful)
        var payload = StepMetricPayload()
        payload.note(source: .landmarkFallback)

        let forwardHeadOffsets = successfulFrames.compactMap { frame -> Double? in
            guard
                let ear = frame.preferredEar,
                let shoulderMid = frame.shoulderMid,
                let hipMid = frame.hipMid
            else { return nil }

            let torsoHeight = max(abs(shoulderMid.y - hipMid.y), 0.01)
            return abs(ear.x - shoulderMid.x) / torsoHeight * 100
        }

        let thoracicCurveScores = successfulFrames.compactMap { frame -> Double? in
            guard
                let ear = frame.preferredEar,
                let shoulderMid = frame.shoulderMid,
                let hipMid = frame.hipMid
            else { return nil }

            let angle = PosePointSample.angleDegrees(a: ear, b: shoulderMid, c: hipMid)
            return ScanMath.clamp(1 - (abs(angle - 165) / 40))
        }

        let lumbarCurveScores = successfulFrames.compactMap { frame -> Double? in
            guard
                let shoulderMid = frame.shoulderMid,
                let hipMid = frame.hipMid,
                let kneeMid = frame.kneeMid
            else { return nil }

            let angle = PosePointSample.angleDegrees(a: shoulderMid, b: hipMid, c: kneeMid)
            return ScanMath.clamp(1 - (abs(angle - 165) / 45))
        }

        let trunkAlignmentScores = successfulFrames.compactMap { frame -> Double? in
            guard
                let shoulderMid = frame.shoulderMid,
                let hipMid = frame.hipMid
            else { return nil }

            let torsoHeight = max(abs(shoulderMid.y - hipMid.y), 0.01)
            return ScanMath.clamp(1 - (abs(shoulderMid.x - hipMid.x) / torsoHeight * 2.5))
        }

        let payloadScore = ScanMath.average([
            thoracicCurveScores.averageOptional,
            lumbarCurveScores.averageOptional,
            trunkAlignmentScores.averageOptional,
        ])

        payload.derivedMetrics = compactMetrics([
            (ScanMetricCatalog.Derived.forwardHeadOffset, forwardHeadOffsets.averageOptional),
            (ScanMetricCatalog.Derived.thoracicCurveScore, thoracicCurveScores.averageOptional),
            (ScanMetricCatalog.Derived.lumbarCurveScore, lumbarCurveScores.averageOptional),
            (ScanMetricCatalog.Derived.trunkAlignmentScore, trunkAlignmentScores.averageOptional),
        ])
        payload.movementQualityScores = compactMetrics([
            (ScanMetricCatalog.MovementQuality.standingSide, payloadScore),
        ])
        return payload
    }
}
