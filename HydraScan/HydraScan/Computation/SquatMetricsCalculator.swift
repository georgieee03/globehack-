import Foundation

enum SquatMetricsCalculator {
    static func evaluate(frames: [CapturedPoseFrame]) -> StepMetricPayload {
        let successfulFrames = frames.filter(\.isSuccessful)
        var payload = StepMetricPayload()

        let rightKneeSeries = ScanMetricResolver.series(for: .rightKneeFlexion, in: successfulFrames)
        let leftKneeSeries = ScanMetricResolver.series(for: .leftKneeFlexion, in: successfulFrames)
        let rightHipSeries = ScanMetricResolver.series(for: .rightHipFlexion, in: successfulFrames)
        let leftHipSeries = ScanMetricResolver.series(for: .leftHipFlexion, in: successfulFrames)
        let rightAnkleSeries = ScanMetricResolver.series(for: .rightAnkleDorsiflexion, in: successfulFrames)
        let leftAnkleSeries = ScanMetricResolver.series(for: .leftAnkleDorsiflexion, in: successfulFrames)

        let rightKneeROM = rightKneeSeries.maxValue
        let leftKneeROM = leftKneeSeries.maxValue
        let rightHipROM = rightHipSeries.maxValue
        let leftHipROM = leftHipSeries.maxValue
        let rightAnkleROM = rightAnkleSeries.maxValue
        let leftAnkleROM = leftAnkleSeries.maxValue

        payload.note(source: rightKneeSeries.source)
        payload.note(source: leftKneeSeries.source)
        payload.note(source: rightHipSeries.source)
        payload.note(source: leftHipSeries.source)
        payload.note(source: rightAnkleSeries.source)
        payload.note(source: leftAnkleSeries.source)
        payload.note(source: .landmarkFallback)

        let kneeTrackingLeft = successfulFrames.compactMap { frame -> Double? in
            guard let knee = frame.leftKnee, let ankle = frame.leftAnkle, let hip = frame.leftHip else { return nil }
            let legLength = max(hip.distance(to: ankle), 0.01)
            return abs(knee.x - ankle.x) / legLength * 100
        }.averageOptional

        let kneeTrackingRight = successfulFrames.compactMap { frame -> Double? in
            guard let knee = frame.rightKnee, let ankle = frame.rightAnkle, let hip = frame.rightHip else { return nil }
            let legLength = max(hip.distance(to: ankle), 0.01)
            return abs(knee.x - ankle.x) / legLength * 100
        }.averageOptional

        let trunkLean = successfulFrames.compactMap { frame -> Double? in
            guard let shoulderMid = frame.shoulderMid, let hipMid = frame.hipMid else { return nil }
            let torsoHeight = max(abs(shoulderMid.y - hipMid.y), 0.01)
            return abs(shoulderMid.x - hipMid.x) / torsoHeight * 100
        }.averageOptional

        let squatDepth = ScanMath.average([rightKneeROM, leftKneeROM])
        let asymmetry = AsymmetryCalculator.percentage(right: rightKneeROM, left: leftKneeROM)
        let hipROMAverage = ScanMath.average([rightHipROM, leftHipROM])
        let ankleROMAverage = ScanMath.average([rightAnkleROM, leftAnkleROM])
        let leftTrackingScore = kneeTrackingLeft.map { ScanMath.clamp(1 - ($0 / 25)) }
        let rightTrackingScore = kneeTrackingRight.map { ScanMath.clamp(1 - ($0 / 25)) }
        let trunkLeanScore = trunkLean.map { ScanMath.clamp(1 - ($0 / 40)) }
        let qualityInputs: [Double?] = [
            ScanMath.normalized(squatDepth, upperBound: 130),
            ScanMath.normalized(hipROMAverage, upperBound: 120),
            ScanMath.normalized(ankleROMAverage, upperBound: 50),
            leftTrackingScore,
            rightTrackingScore,
            trunkLeanScore,
            AsymmetryCalculator.normalizedSymmetryScore(asymmetry: asymmetry),
        ]
        let quality = ScanMath.average(qualityInputs)

        payload.romValues = compactMetrics([
            (ScanMetricCatalog.ROM.rightHipFlexion, rightHipROM),
            (ScanMetricCatalog.ROM.leftHipFlexion, leftHipROM),
            (ScanMetricCatalog.ROM.rightKneeFlexion, rightKneeROM),
            (ScanMetricCatalog.ROM.leftKneeFlexion, leftKneeROM),
            (ScanMetricCatalog.ROM.rightAnkleDorsiflexion, rightAnkleROM),
            (ScanMetricCatalog.ROM.leftAnkleDorsiflexion, leftAnkleROM),
        ])
        payload.asymmetryScores = compactMetrics([
            (ScanMetricCatalog.Asymmetry.kneeFlexion, asymmetry),
            (ScanMetricCatalog.Asymmetry.ankleDorsiflexion, AsymmetryCalculator.percentage(right: rightAnkleROM, left: leftAnkleROM)),
        ])
        payload.movementQualityScores = compactMetrics([
            (ScanMetricCatalog.MovementQuality.squat, quality),
        ])
        payload.derivedMetrics = compactMetrics([
            (ScanMetricCatalog.Derived.squatDepth, squatDepth),
            (ScanMetricCatalog.Derived.kneeTrackingLeft, kneeTrackingLeft),
            (ScanMetricCatalog.Derived.kneeTrackingRight, kneeTrackingRight),
            (ScanMetricCatalog.Derived.trunkLean, trunkLean),
            (ScanMetricCatalog.Derived.ankleMobilityLeft, leftAnkleROM),
            (ScanMetricCatalog.Derived.ankleMobilityRight, rightAnkleROM),
        ])

        let repCount = rightKneeSeries.estimatedRepCount
        if repCount > 0 {
            payload.repSummaries = [
                RepSummary(
                    movement: ScanMetricCatalog.MovementQuality.squat,
                    count: repCount,
                    peakAngles: compactMetrics([
                        ("right_knee", rightKneeROM),
                        ("left_knee", leftKneeROM),
                        ("right_hip", rightHipROM),
                        ("left_hip", leftHipROM),
                    ]),
                    troughAngles: compactMetrics([
                        ("right_knee", rightKneeSeries.minValue),
                        ("left_knee", leftKneeSeries.minValue),
                        ("right_hip", rightHipSeries.minValue),
                        ("left_hip", leftHipSeries.minValue),
                    ])
                )
            ]
        }

        return payload
    }
}
