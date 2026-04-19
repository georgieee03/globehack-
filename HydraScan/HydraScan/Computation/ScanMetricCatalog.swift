import Foundation

enum ScanMetricCatalog {
    enum MetricCategory {
        case generic
        case rom
        case asymmetry
        case movementQuality
        case gait
        case derived
    }

    static let schemaVersion = 2

    static let aggregateROMKeys: [String] = [
        ROM.leftShoulderFlexion,
        ROM.rightShoulderFlexion,
        ROM.leftHipFlexion,
        ROM.rightHipFlexion,
        ROM.leftKneeFlexion,
        ROM.rightKneeFlexion,
        ROM.leftAnkleDorsiflexion,
        ROM.rightAnkleDorsiflexion,
        ROM.spinalFlexion,
    ]

    static let aggregateAsymmetryKeys: [String] = [
        Asymmetry.shoulderFlexion,
        Asymmetry.hipFlexion,
        Asymmetry.kneeFlexion,
        Asymmetry.ankleDorsiflexion,
        Asymmetry.singleLegBalance,
    ]

    static let aggregateMovementQualityKeys: [String] = [
        MovementQuality.standingFront,
        MovementQuality.standingSide,
        MovementQuality.shoulderFlexion,
        MovementQuality.squat,
        MovementQuality.hipHinge,
        MovementQuality.singleLegBalanceRight,
        MovementQuality.singleLegBalanceLeft,
    ]

    static let aggregateGaitKeys: [String] = [
        Gait.rightBalanceSway,
        Gait.leftBalanceSway,
        Gait.rightAnkleWobble,
        Gait.leftAnkleWobble,
    ]

    enum ROM {
        static let leftShoulderFlexion = "left_shoulder_flexion"
        static let rightShoulderFlexion = "right_shoulder_flexion"
        static let leftHipFlexion = "left_hip_flexion"
        static let rightHipFlexion = "right_hip_flexion"
        static let leftKneeFlexion = "left_knee_flexion"
        static let rightKneeFlexion = "right_knee_flexion"
        static let leftAnkleDorsiflexion = "left_ankle_dorsiflexion"
        static let rightAnkleDorsiflexion = "right_ankle_dorsiflexion"
        static let spinalFlexion = "spinal_flexion"
    }

    enum Asymmetry {
        static let shoulderFlexion = "shoulder_flexion"
        static let hipFlexion = "hip_flexion"
        static let kneeFlexion = "knee_flexion"
        static let ankleDorsiflexion = "ankle_dorsiflexion"
        static let singleLegBalance = "single_leg_balance"
    }

    enum MovementQuality {
        static let standingFront = "standing_front"
        static let standingSide = "standing_side"
        static let shoulderFlexion = "shoulder_flexion"
        static let squat = "squat"
        static let hipHinge = "hip_hinge"
        static let singleLegBalanceRight = "single_leg_balance_right"
        static let singleLegBalanceLeft = "single_leg_balance_left"
    }

    enum Gait {
        static let rightBalanceSway = "right_balance_sway"
        static let leftBalanceSway = "left_balance_sway"
        static let rightAnkleWobble = "right_ankle_wobble"
        static let leftAnkleWobble = "left_ankle_wobble"
    }

    enum Derived {
        static let shoulderLevelOffset = "shoulder_level_offset"
        static let hipLevelOffset = "hip_level_offset"
        static let kneeAlignmentOffset = "knee_alignment_offset"
        static let frontalPostureScore = "frontal_posture_score"
        static let forwardHeadOffset = "forward_head_offset"
        static let thoracicCurveScore = "thoracic_curve_score"
        static let lumbarCurveScore = "lumbar_curve_score"
        static let trunkAlignmentScore = "trunk_alignment_score"
        static let squatDepth = "squat_depth"
        static let kneeTrackingLeft = "knee_tracking_left"
        static let kneeTrackingRight = "knee_tracking_right"
        static let trunkLean = "trunk_lean"
        static let ankleMobilityLeft = "ankle_mobility_left"
        static let ankleMobilityRight = "ankle_mobility_right"
        static let hipROMLeft = "hip_rom_left"
        static let hipROMRight = "hip_rom_right"
        static let lumbarFlexion = "lumbar_flexion"
        static let hamstringFlexibilityLeft = "hamstring_flexibility_left"
        static let hamstringFlexibilityRight = "hamstring_flexibility_right"
        static let stabilityScore = "stability_score"
        static let ankleWobble = "ankle_wobble"
        static let compensationScore = "compensation_score"
        static let swayDistance = "sway_distance"
        static let balanceAsymmetry = "balance_asymmetry"
    }

    private static let romLabels: [String: String] = [
        ROM.leftShoulderFlexion: "Left Shoulder Flexion",
        ROM.rightShoulderFlexion: "Right Shoulder Flexion",
        ROM.leftHipFlexion: "Left Hip Flexion",
        ROM.rightHipFlexion: "Right Hip Flexion",
        ROM.leftKneeFlexion: "Left Knee Flexion",
        ROM.rightKneeFlexion: "Right Knee Flexion",
        ROM.leftAnkleDorsiflexion: "Left Ankle Dorsiflexion",
        ROM.rightAnkleDorsiflexion: "Right Ankle Dorsiflexion",
        ROM.spinalFlexion: "Spinal Flexion",
    ]

    private static let asymmetryLabels: [String: String] = [
        Asymmetry.shoulderFlexion: "Shoulder Flexion Asymmetry",
        Asymmetry.hipFlexion: "Hip Flexion Asymmetry",
        Asymmetry.kneeFlexion: "Knee Flexion Asymmetry",
        Asymmetry.ankleDorsiflexion: "Ankle Dorsiflexion Asymmetry",
        Asymmetry.singleLegBalance: "Single-Leg Balance Asymmetry",
    ]

    private static let movementQualityLabels: [String: String] = [
        MovementQuality.standingFront: "Standing Front Quality",
        MovementQuality.standingSide: "Standing Side Quality",
        MovementQuality.shoulderFlexion: "Shoulder Flexion Quality",
        MovementQuality.squat: "Squat Quality",
        MovementQuality.hipHinge: "Hip Hinge Quality",
        MovementQuality.singleLegBalanceRight: "Right Balance Quality",
        MovementQuality.singleLegBalanceLeft: "Left Balance Quality",
    ]

    private static let gaitLabels: [String: String] = [
        Gait.rightBalanceSway: "Right Balance Sway",
        Gait.leftBalanceSway: "Left Balance Sway",
        Gait.rightAnkleWobble: "Right Ankle Wobble",
        Gait.leftAnkleWobble: "Left Ankle Wobble",
    ]

    private static let derivedLabels: [String: String] = [
        Derived.shoulderLevelOffset: "Shoulder Level Offset",
        Derived.hipLevelOffset: "Hip Level Offset",
        Derived.kneeAlignmentOffset: "Knee Alignment Offset",
        Derived.frontalPostureScore: "Frontal Posture Score",
        Derived.forwardHeadOffset: "Forward Head Offset",
        Derived.thoracicCurveScore: "Thoracic Curve Score",
        Derived.lumbarCurveScore: "Lumbar Curve Score",
        Derived.trunkAlignmentScore: "Trunk Alignment Score",
        Derived.squatDepth: "Squat Depth",
        Derived.kneeTrackingLeft: "Left Knee Tracking",
        Derived.kneeTrackingRight: "Right Knee Tracking",
        Derived.trunkLean: "Trunk Lean",
        Derived.ankleMobilityLeft: "Left Ankle Mobility",
        Derived.ankleMobilityRight: "Right Ankle Mobility",
        Derived.hipROMLeft: "Left Hip ROM",
        Derived.hipROMRight: "Right Hip ROM",
        Derived.lumbarFlexion: "Lumbar Flexion",
        Derived.hamstringFlexibilityLeft: "Left Hamstring Flexibility",
        Derived.hamstringFlexibilityRight: "Right Hamstring Flexibility",
        Derived.stabilityScore: "Stability Score",
        Derived.ankleWobble: "Ankle Wobble",
        Derived.compensationScore: "Compensation Score",
        Derived.swayDistance: "Sway Distance",
        Derived.balanceAsymmetry: "Balance Asymmetry",
    ]

    private static let genericLabels: [String: String] = {
        var labels = romLabels
        labels.merge(gaitLabels) { current, _ in current }
        labels.merge(derivedLabels) { current, _ in current }

        // Build these neutral labels pair-by-pair so overlapping raw keys like
        // "shoulder_flexion" never trip Swift's duplicate-key dictionary trap.
        let neutralLabels: [(String, String)] = [
            (Asymmetry.shoulderFlexion, "Shoulder Flexion"),
            (Asymmetry.hipFlexion, "Hip Flexion"),
            (Asymmetry.kneeFlexion, "Knee Flexion"),
            (Asymmetry.ankleDorsiflexion, "Ankle Dorsiflexion"),
            (Asymmetry.singleLegBalance, "Single-Leg Balance"),
            (MovementQuality.standingFront, "Standing Front"),
            (MovementQuality.standingSide, "Standing Side"),
            (MovementQuality.shoulderFlexion, "Shoulder Flexion"),
            (MovementQuality.squat, "Squat"),
            (MovementQuality.hipHinge, "Hip Hinge"),
            (MovementQuality.singleLegBalanceRight, "Right Single-Leg Balance"),
            (MovementQuality.singleLegBalanceLeft, "Left Single-Leg Balance"),
        ]

        for (key, value) in neutralLabels where labels[key] == nil {
            labels[key] = value
        }

        return labels
    }()

    static func label(for key: String, category: MetricCategory = .generic) -> String {
        let labels: [String: String]

        switch category {
        case .generic:
            labels = genericLabels
        case .rom:
            labels = romLabels
        case .asymmetry:
            labels = asymmetryLabels
        case .movementQuality:
            labels = movementQualityLabels
        case .gait:
            labels = gaitLabels
        case .derived:
            labels = derivedLabels
        }

        return labels[key] ?? key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func title(for step: CaptureStep) -> String {
        switch step {
        case .standingFront:
            return "Standing Front"
        case .standingSide:
            return "Standing Side"
        case .shoulderFlexion:
            return "Shoulder Flexion"
        case .squat:
            return "Squat"
        case .hipHinge:
            return "Hip Hinge"
        case .singleLegBalanceRight:
            return "Right Single-Leg Balance"
        case .singleLegBalanceLeft:
            return "Left Single-Leg Balance"
        }
    }
}

struct StepMetricPayload {
    var jointAngles: [String: Double] = [:]
    var romValues: [String: Double] = [:]
    var asymmetryScores: [String: Double] = [:]
    var movementQualityScores: [String: Double] = [:]
    var gaitMetrics: [String: Double] = [:]
    var derivedMetrics: [String: Double] = [:]
    var repSummaries: [RepSummary] = []
    var computationSources: Set<QuickPoseComputationSource> = []

    mutating func note(source: QuickPoseComputationSource?) {
        if let source {
            computationSources.insert(source)
        }
    }

    mutating func merge(_ other: StepMetricPayload) {
        jointAngles.merge(other.jointAngles) { _, new in new }
        romValues.merge(other.romValues) { _, new in new }
        asymmetryScores.merge(other.asymmetryScores) { _, new in new }
        movementQualityScores.merge(other.movementQualityScores) { _, new in new }
        gaitMetrics.merge(other.gaitMetrics) { _, new in new }
        derivedMetrics.merge(other.derivedMetrics) { _, new in new }
        repSummaries.append(contentsOf: other.repSummaries)
        computationSources.formUnion(other.computationSources)
    }
}

enum ScanResolvedMetric: String, CaseIterable {
    case rightShoulderFlexion
    case leftShoulderFlexion
    case rightHipFlexion
    case leftHipFlexion
    case rightKneeFlexion
    case leftKneeFlexion
    case rightAnkleDorsiflexion
    case leftAnkleDorsiflexion
    case spinalFlexion
}

struct ResolvedMetricSeries {
    let metric: ScanResolvedMetric
    let values: [Double]
    let source: QuickPoseComputationSource?

    var maxValue: Double? { values.max() }
    var latestValue: Double? { values.last }
    var minValue: Double? { values.min() }

    var estimatedRepCount: Int {
        guard
            let minimum = values.min(),
            let maximum = values.max(),
            maximum - minimum >= 10
        else {
            return 0
        }

        let highThreshold = minimum + ((maximum - minimum) * 0.7)
        let lowThreshold = minimum + ((maximum - minimum) * 0.35)
        var count = 0
        var aboveHighThreshold = false

        for sample in values {
            if !aboveHighThreshold, sample >= highThreshold {
                aboveHighThreshold = true
            } else if aboveHighThreshold, sample <= lowThreshold {
                count += 1
                aboveHighThreshold = false
            }
        }

        return count
    }
}

enum ScanMetricResolver {
    static func series(
        for metric: ScanResolvedMetric,
        in frames: [CapturedPoseFrame]
    ) -> ResolvedMetricSeries {
        let featureSeries = featureValues(for: metric, in: frames)
        let fallbackSeries = frames.compactMap { fallbackValue(for: metric, frame: $0) }

        if featureSeries.count >= 3 {
            return ResolvedMetricSeries(metric: metric, values: featureSeries, source: .featureSeries)
        }

        if !fallbackSeries.isEmpty {
            return ResolvedMetricSeries(metric: metric, values: fallbackSeries, source: .landmarkFallback)
        }

        if !featureSeries.isEmpty {
            return ResolvedMetricSeries(metric: metric, values: featureSeries, source: .featureSeries)
        }

        return ResolvedMetricSeries(metric: metric, values: [], source: nil)
    }

    private static func featureValues(
        for metric: ScanResolvedMetric,
        in frames: [CapturedPoseFrame]
    ) -> [Double] {
        let aliases = featureAliases(for: metric)
        guard !aliases.isEmpty else { return [] }

        return frames.compactMap { frame in
            aliases.compactMap { alias in
                frame.artifact.metrics.first(where: { $0.name == alias })?.value
            }.first
        }
    }

    private static func featureAliases(for metric: ScanResolvedMetric) -> [String] {
        switch metric {
        case .rightShoulderFlexion:
            return ["Right Shoulder", "Shoulder Right", "Right shoulder"]
        case .leftShoulderFlexion:
            return ["Left Shoulder", "Shoulder Left", "Left shoulder"]
        case .rightHipFlexion:
            return ["Right Hip", "Hip Right", "Right hip"]
        case .leftHipFlexion:
            return ["Left Hip", "Hip Left", "Left hip"]
        case .rightKneeFlexion:
            return ["Right Knee", "Knee Right", "Right knee"]
        case .leftKneeFlexion:
            return ["Left Knee", "Knee Left", "Left knee"]
        case .rightAnkleDorsiflexion:
            return ["Right Ankle", "Ankle Right", "Right ankle"]
        case .leftAnkleDorsiflexion:
            return ["Left Ankle", "Ankle Left", "Left ankle"]
        case .spinalFlexion:
            return ["Back", "Spinal Flexion", "Lumbar Flexion"]
        }
    }

    private static func fallbackValue(
        for metric: ScanResolvedMetric,
        frame: CapturedPoseFrame
    ) -> Double? {
        switch metric {
        case .rightShoulderFlexion:
            return shoulderFlexion(elbow: frame.rightElbow, shoulder: frame.rightShoulder, hip: frame.rightHip ?? frame.hipMid)
        case .leftShoulderFlexion:
            return shoulderFlexion(elbow: frame.leftElbow, shoulder: frame.leftShoulder, hip: frame.leftHip ?? frame.hipMid)
        case .rightHipFlexion:
            return hipFlexion(shoulder: frame.rightShoulder ?? frame.shoulderMid, hip: frame.rightHip, knee: frame.rightKnee)
        case .leftHipFlexion:
            return hipFlexion(shoulder: frame.leftShoulder ?? frame.shoulderMid, hip: frame.leftHip, knee: frame.leftKnee)
        case .rightKneeFlexion:
            return kneeFlexion(hip: frame.rightHip, knee: frame.rightKnee, ankle: frame.rightAnkle)
        case .leftKneeFlexion:
            return kneeFlexion(hip: frame.leftHip, knee: frame.leftKnee, ankle: frame.leftAnkle)
        case .rightAnkleDorsiflexion:
            return ankleDorsiflexion(knee: frame.rightKnee, ankle: frame.rightAnkle)
        case .leftAnkleDorsiflexion:
            return ankleDorsiflexion(knee: frame.leftKnee, ankle: frame.leftAnkle)
        case .spinalFlexion:
            return spinalFlexion(shoulderMid: frame.shoulderMid, hipMid: frame.hipMid, kneeMid: frame.kneeMid)
        }
    }

    private static func shoulderFlexion(
        elbow: PosePointSample?,
        shoulder: PosePointSample?,
        hip: PosePointSample?
    ) -> Double? {
        guard let elbow, let shoulder, let hip else { return nil }
        return normalizedAngle(PosePointSample.angleDegrees(a: elbow, b: shoulder, c: hip))
    }

    private static func hipFlexion(
        shoulder: PosePointSample?,
        hip: PosePointSample?,
        knee: PosePointSample?
    ) -> Double? {
        guard let shoulder, let hip, let knee else { return nil }
        let extensionAngle = PosePointSample.angleDegrees(a: shoulder, b: hip, c: knee)
        return normalizedAngle(180 - extensionAngle)
    }

    private static func kneeFlexion(
        hip: PosePointSample?,
        knee: PosePointSample?,
        ankle: PosePointSample?
    ) -> Double? {
        guard let hip, let knee, let ankle else { return nil }
        let extensionAngle = PosePointSample.angleDegrees(a: hip, b: knee, c: ankle)
        return normalizedAngle(180 - extensionAngle)
    }

    private static func spinalFlexion(
        shoulderMid: PosePointSample?,
        hipMid: PosePointSample?,
        kneeMid: PosePointSample?
    ) -> Double? {
        guard let shoulderMid, let hipMid, let kneeMid else { return nil }
        let extensionAngle = PosePointSample.angleDegrees(a: shoulderMid, b: hipMid, c: kneeMid)
        return normalizedAngle(180 - extensionAngle)
    }

    private static func ankleDorsiflexion(
        knee: PosePointSample?,
        ankle: PosePointSample?
    ) -> Double? {
        guard let knee, let ankle else { return nil }
        let verticalDistance = max(abs(knee.y - ankle.y), 0.0001)
        let horizontalDistance = abs(knee.x - ankle.x)
        return atan2(horizontalDistance, verticalDistance) * 180 / .pi
    }

    private static func normalizedAngle(_ value: Double) -> Double {
        min(max(value, 0), 180)
    }
}

enum ScanMath {
    static func clamp(_ value: Double, lower: Double = 0, upper: Double = 1) -> Double {
        min(max(value, lower), upper)
    }

    static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func average(_ values: [Double?]) -> Double? {
        average(values.compactMap { $0 })
    }

    static func normalized(_ value: Double?, upperBound: Double) -> Double? {
        guard let value, upperBound > 0 else { return nil }
        return clamp(value / upperBound, lower: 0, upper: 1)
    }

    static func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count > 1, let mean = average(values) else { return nil }
        let variance = values.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(values.count)
        return sqrt(variance)
    }
}

func compactMetrics(_ pairs: [(String, Double?)]) -> [String: Double] {
    var result: [String: Double] = [:]
    for (key, value) in pairs {
        if let value {
            result[key] = value
        }
    }
    return result
}

extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    var averageOptional: Double? {
        isEmpty ? nil : average
    }
}
