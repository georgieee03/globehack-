import Foundation

enum QuickPoseComputationSource: String, Codable, Hashable {
    case featureSeries = "feature_series"
    case landmarkFallback = "landmark_fallback"
    case mixed
}

enum QuickPoseStepCompletenessStatus: String, Codable, Hashable {
    case complete
    case partial
    case insufficientSignal = "insufficient_signal"
}

struct QuickPoseStepResult: Identifiable, Codable, Hashable {
    var id: String { "\(step.rawValue)-\(startedAt.iso8601String)" }
    var step: CaptureStep
    var startedAt: Date
    var completedAt: Date
    var confidence: Double
    var landmarks: [LandmarkFrame]
    var jointAngles: [String: Double]
    var romValues: [String: Double]
    var asymmetryScores: [String: Double]
    var movementQualityScores: [String: Double]
    var gaitMetrics: [String: Double]
    var repSummaries: [RepSummary]
    var derivedMetrics: [String: Double]
    var computationSource: QuickPoseComputationSource
    var completenessStatus: QuickPoseStepCompletenessStatus
    var missingMetricKeys: [String]

    enum CodingKeys: String, CodingKey {
        case step
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case confidence
        case landmarks
        case jointAngles = "joint_angles"
        case romValues = "rom_values"
        case asymmetryScores = "asymmetry_scores"
        case movementQualityScores = "movement_quality_scores"
        case gaitMetrics = "gait_metrics"
        case repSummaries = "rep_summaries"
        case derivedMetrics = "derived_metrics"
        case computationSource = "computation_source"
        case completenessStatus = "completeness_status"
        case missingMetricKeys = "missing_metric_keys"
    }

    init(
        step: CaptureStep,
        startedAt: Date,
        completedAt: Date,
        confidence: Double,
        landmarks: [LandmarkFrame],
        jointAngles: [String: Double],
        romValues: [String: Double],
        asymmetryScores: [String: Double],
        movementQualityScores: [String: Double],
        gaitMetrics: [String: Double],
        repSummaries: [RepSummary],
        derivedMetrics: [String: Double],
        computationSource: QuickPoseComputationSource = .landmarkFallback,
        completenessStatus: QuickPoseStepCompletenessStatus = .insufficientSignal,
        missingMetricKeys: [String] = []
    ) {
        self.step = step
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.confidence = confidence
        self.landmarks = landmarks
        self.jointAngles = jointAngles
        self.romValues = romValues
        self.asymmetryScores = asymmetryScores
        self.movementQualityScores = movementQualityScores
        self.gaitMetrics = gaitMetrics
        self.repSummaries = repSummaries
        self.derivedMetrics = derivedMetrics
        self.computationSource = computationSource
        self.completenessStatus = completenessStatus
        self.missingMetricKeys = missingMetricKeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            step: try container.decode(CaptureStep.self, forKey: .step),
            startedAt: try container.decode(Date.self, forKey: .startedAt),
            completedAt: try container.decode(Date.self, forKey: .completedAt),
            confidence: try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0,
            landmarks: try container.decodeIfPresent([LandmarkFrame].self, forKey: .landmarks) ?? [],
            jointAngles: try container.decodeIfPresent([String: Double].self, forKey: .jointAngles) ?? [:],
            romValues: try container.decodeIfPresent([String: Double].self, forKey: .romValues) ?? [:],
            asymmetryScores: try container.decodeIfPresent([String: Double].self, forKey: .asymmetryScores) ?? [:],
            movementQualityScores: try container.decodeIfPresent([String: Double].self, forKey: .movementQualityScores) ?? [:],
            gaitMetrics: try container.decodeIfPresent([String: Double].self, forKey: .gaitMetrics) ?? [:],
            repSummaries: try container.decodeIfPresent([RepSummary].self, forKey: .repSummaries) ?? [],
            derivedMetrics: try container.decodeIfPresent([String: Double].self, forKey: .derivedMetrics) ?? [:],
            computationSource: try container.decodeIfPresent(QuickPoseComputationSource.self, forKey: .computationSource) ?? .landmarkFallback,
            completenessStatus: try container.decodeIfPresent(QuickPoseStepCompletenessStatus.self, forKey: .completenessStatus) ?? .insufficientSignal,
            missingMetricKeys: try container.decodeIfPresent([String].self, forKey: .missingMetricKeys) ?? []
        )
    }

    func presentationSnapshot() -> QuickPoseStepResult {
        QuickPoseStepResult(
            step: step,
            startedAt: startedAt,
            completedAt: completedAt,
            confidence: confidence,
            landmarks: [],
            jointAngles: jointAngles,
            romValues: romValues,
            asymmetryScores: asymmetryScores,
            movementQualityScores: movementQualityScores,
            gaitMetrics: gaitMetrics,
            repSummaries: repSummaries,
            derivedMetrics: derivedMetrics,
            computationSource: computationSource,
            completenessStatus: completenessStatus,
            missingMetricKeys: missingMetricKeys
        )
    }
}
