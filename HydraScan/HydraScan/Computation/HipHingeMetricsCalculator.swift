import Foundation

enum HipHingeMetricsCalculator {
    static func evaluate(frames: [CapturedPoseFrame]) -> StepMetricPayload {
        let successfulFrames = frames.filter(\.isSuccessful)
        var payload = StepMetricPayload()

        let rightHipSeries = ScanMetricResolver.series(for: .rightHipFlexion, in: successfulFrames)
        let leftHipSeries = ScanMetricResolver.series(for: .leftHipFlexion, in: successfulFrames)
        let spinalSeries = ScanMetricResolver.series(for: .spinalFlexion, in: successfulFrames)
        let rightKneeSeries = ScanMetricResolver.series(for: .rightKneeFlexion, in: successfulFrames)
        let leftKneeSeries = ScanMetricResolver.series(for: .leftKneeFlexion, in: successfulFrames)

        let rightHipROM = rightHipSeries.maxValue
        let leftHipROM = leftHipSeries.maxValue
        let lumbarFlexion = spinalSeries.maxValue
        let rightKneeFlexion = rightKneeSeries.maxValue
        let leftKneeFlexion = leftKneeSeries.maxValue

        payload.note(source: rightHipSeries.source)
        payload.note(source: leftHipSeries.source)
        payload.note(source: spinalSeries.source)
        payload.note(source: rightKneeSeries.source)
        payload.note(source: leftKneeSeries.source)

        let hamstringLeft = hipHingeProxy(hipROM: leftHipROM, kneeFlexion: leftKneeFlexion)
        let hamstringRight = hipHingeProxy(hipROM: rightHipROM, kneeFlexion: rightKneeFlexion)
        let asymmetry = AsymmetryCalculator.percentage(right: rightHipROM, left: leftHipROM)

        let quality = ScanMath.average([
            ScanMath.normalized(ScanMath.average([rightHipROM, leftHipROM]), upperBound: 120),
            ScanMath.normalized(lumbarFlexion, upperBound: 85),
            hamstringLeft.map { ScanMath.clamp($0 / 110) },
            hamstringRight.map { ScanMath.clamp($0 / 110) },
            AsymmetryCalculator.normalizedSymmetryScore(asymmetry: asymmetry),
        ])

        payload.romValues = compactMetrics([
            (ScanMetricCatalog.ROM.rightHipFlexion, rightHipROM),
            (ScanMetricCatalog.ROM.leftHipFlexion, leftHipROM),
            (ScanMetricCatalog.ROM.spinalFlexion, lumbarFlexion),
        ])
        payload.asymmetryScores = compactMetrics([
            (ScanMetricCatalog.Asymmetry.hipFlexion, asymmetry),
        ])
        payload.movementQualityScores = compactMetrics([
            (ScanMetricCatalog.MovementQuality.hipHinge, quality),
        ])
        payload.derivedMetrics = compactMetrics([
            (ScanMetricCatalog.Derived.hipROMRight, rightHipROM),
            (ScanMetricCatalog.Derived.hipROMLeft, leftHipROM),
            (ScanMetricCatalog.Derived.lumbarFlexion, lumbarFlexion),
            (ScanMetricCatalog.Derived.hamstringFlexibilityRight, hamstringRight),
            (ScanMetricCatalog.Derived.hamstringFlexibilityLeft, hamstringLeft),
        ])

        let repCount = rightHipSeries.estimatedRepCount
        if repCount > 0 {
            payload.repSummaries = [
                RepSummary(
                    movement: ScanMetricCatalog.MovementQuality.hipHinge,
                    count: repCount,
                    peakAngles: compactMetrics([
                        ("right_hip", rightHipROM),
                        ("left_hip", leftHipROM),
                        ("spine", lumbarFlexion),
                    ]),
                    troughAngles: compactMetrics([
                        ("right_hip", rightHipSeries.minValue),
                        ("left_hip", leftHipSeries.minValue),
                        ("spine", spinalSeries.minValue),
                    ])
                )
            ]
        }

        return payload
    }

    private static func hipHingeProxy(hipROM: Double?, kneeFlexion: Double?) -> Double? {
        guard let hipROM else { return nil }
        let kneePenalty = (kneeFlexion ?? 0) * 0.2
        return max(hipROM - kneePenalty, 0)
    }
}
