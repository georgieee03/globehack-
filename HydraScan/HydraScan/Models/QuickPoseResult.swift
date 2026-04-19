import Foundation

struct Landmark: Identifiable, Codable, Hashable {
    var id: Int { index }
    var index: Int
    var x: Double
    var y: Double
    var z: Double
    var visibility: Double
}

struct LandmarkFrame: Identifiable, Codable, Hashable {
    var id = UUID()
    var capturedAt: Date
    var landmarks: [Landmark]
}

struct RepSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var movement: String
    var count: Int
    var peakAngles: [String: Double]
    var troughAngles: [String: Double]

    enum CodingKeys: String, CodingKey {
        case movement
        case count
        case peakAngles = "peak_angles"
        case troughAngles = "trough_angles"
    }
}

struct QuickPoseResult: Codable, Hashable {
    var schemaVersion: Int
    var stepResults: [QuickPoseStepResult]
    var landmarks: [LandmarkFrame]
    var jointAngles: [String: Double]
    var romValues: [String: Double]
    var asymmetryScores: [String: Double]
    var movementQualityScores: [String: Double]
    var gaitMetrics: [String: Double]
    var repSummaries: [RepSummary]
    var capturedAt: Date

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case stepResults = "step_results"
        case capturedAt = "captured_at"
        case landmarks
        case jointAngles = "joint_angles"
        case romValues = "rom_values"
        case asymmetryScores = "asymmetry_scores"
        case movementQualityScores = "movement_quality_scores"
        case gaitMetrics = "gait_metrics"
        case repSummaries = "rep_summaries"
        case aggregateRomValues = "aggregate_rom_values"
        case aggregateAsymmetryScores = "aggregate_asymmetry_scores"
        case aggregateMovementQualityScores = "aggregate_movement_quality_scores"
        case aggregateGaitMetrics = "aggregate_gait_metrics"

        // Legacy payload keys from earlier app builds.
        case legacyJointAngles = "jointAngles"
        case legacyRomValues = "romValues"
        case legacyAsymmetryScores = "asymmetryScores"
        case legacyMovementQualityScores = "movementQualityScores"
        case legacyGaitMetrics = "gaitMetrics"
        case legacyRepSummaries = "repSummaries"
        case legacyCapturedAt = "capturedAt"
    }

    init(
        schemaVersion: Int = 2,
        stepResults: [QuickPoseStepResult],
        landmarks: [LandmarkFrame],
        jointAngles: [String: Double],
        romValues: [String: Double],
        asymmetryScores: [String: Double],
        movementQualityScores: [String: Double],
        gaitMetrics: [String: Double],
        repSummaries: [RepSummary],
        capturedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.stepResults = stepResults
        self.landmarks = landmarks
        self.jointAngles = jointAngles
        self.romValues = romValues
        self.asymmetryScores = asymmetryScores
        self.movementQualityScores = movementQualityScores
        self.gaitMetrics = gaitMetrics
        self.repSummaries = repSummaries
        self.capturedAt = capturedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let stepResults = try container.decodeIfPresent([QuickPoseStepResult].self, forKey: .stepResults) ?? []
        let schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? (stepResults.isEmpty ? 1 : 2)

        let landmarks = try container.decodeIfPresent([LandmarkFrame].self, forKey: .landmarks)
            ?? stepResults.flatMap(\.landmarks)
        let decodedJointAngles = try container.decodeIfPresent([String: Double].self, forKey: .jointAngles)
        let legacyJointAngles = try container.decodeIfPresent([String: Double].self, forKey: .legacyJointAngles)
        let jointAngles = decodedJointAngles
            ?? legacyJointAngles
            ?? stepResults.reduce(into: [:]) { result, step in
                result.merge(step.jointAngles) { _, new in new }
            }
        let decodedRomValues = try container.decodeIfPresent([String: Double].self, forKey: .aggregateRomValues)
        let legacyRomValues = try container.decodeIfPresent([String: Double].self, forKey: .romValues)
        let camelRomValues = try container.decodeIfPresent([String: Double].self, forKey: .legacyRomValues)
        let romValues = decodedRomValues
            ?? legacyRomValues
            ?? camelRomValues
            ?? stepResults.reduce(into: [:]) { result, step in
                result.merge(step.romValues) { _, new in new }
            }
        let decodedAsymmetryScores = try container.decodeIfPresent([String: Double].self, forKey: .aggregateAsymmetryScores)
        let legacyAsymmetryScores = try container.decodeIfPresent([String: Double].self, forKey: .asymmetryScores)
        let camelAsymmetryScores = try container.decodeIfPresent([String: Double].self, forKey: .legacyAsymmetryScores)
        let asymmetryScores = decodedAsymmetryScores
            ?? legacyAsymmetryScores
            ?? camelAsymmetryScores
            ?? stepResults.reduce(into: [:]) { result, step in
                result.merge(step.asymmetryScores) { _, new in new }
            }
        let decodedMovementQualityScores = try container.decodeIfPresent([String: Double].self, forKey: .aggregateMovementQualityScores)
        let legacyMovementQualityScores = try container.decodeIfPresent([String: Double].self, forKey: .movementQualityScores)
        let camelMovementQualityScores = try container.decodeIfPresent([String: Double].self, forKey: .legacyMovementQualityScores)
        let movementQualityScores = decodedMovementQualityScores
            ?? legacyMovementQualityScores
            ?? camelMovementQualityScores
            ?? stepResults.reduce(into: [:]) { result, step in
                result.merge(step.movementQualityScores) { _, new in new }
            }
        let decodedGaitMetrics = try container.decodeIfPresent([String: Double].self, forKey: .aggregateGaitMetrics)
        let legacyGaitMetrics = try container.decodeIfPresent([String: Double].self, forKey: .gaitMetrics)
        let camelGaitMetrics = try container.decodeIfPresent([String: Double].self, forKey: .legacyGaitMetrics)
        let gaitMetrics = decodedGaitMetrics
            ?? legacyGaitMetrics
            ?? camelGaitMetrics
            ?? stepResults.reduce(into: [:]) { result, step in
                result.merge(step.gaitMetrics) { _, new in new }
            }
        let decodedRepSummaries = try container.decodeIfPresent([RepSummary].self, forKey: .repSummaries)
        let legacyRepSummaries = try container.decodeIfPresent([RepSummary].self, forKey: .legacyRepSummaries)
        let repSummaries = decodedRepSummaries
            ?? legacyRepSummaries
            ?? stepResults.flatMap(\.repSummaries)
        let decodedCapturedAt = try container.decodeIfPresent(Date.self, forKey: .capturedAt)
        let legacyCapturedAt = try container.decodeIfPresent(Date.self, forKey: .legacyCapturedAt)
        let capturedAt = decodedCapturedAt
            ?? legacyCapturedAt
            ?? stepResults.last?.completedAt
            ?? Date()

        self.init(
            schemaVersion: schemaVersion,
            stepResults: stepResults,
            landmarks: landmarks,
            jointAngles: jointAngles,
            romValues: romValues,
            asymmetryScores: asymmetryScores,
            movementQualityScores: movementQualityScores,
            gaitMetrics: gaitMetrics,
            repSummaries: repSummaries,
            capturedAt: capturedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(stepResults, forKey: .stepResults)
        try container.encode(capturedAt, forKey: .capturedAt)
        try container.encode(romValues, forKey: .aggregateRomValues)
        try container.encode(asymmetryScores, forKey: .aggregateAsymmetryScores)
        try container.encode(movementQualityScores, forKey: .aggregateMovementQualityScores)
        try container.encode(gaitMetrics, forKey: .aggregateGaitMetrics)
        try container.encode(landmarks, forKey: .landmarks)
        try container.encode(jointAngles, forKey: .jointAngles)
        try container.encode(repSummaries, forKey: .repSummaries)
    }

    static let empty = QuickPoseResult(
        stepResults: [],
        landmarks: [],
        jointAngles: [:],
        romValues: [:],
        asymmetryScores: [:],
        movementQualityScores: [:],
        gaitMetrics: [:],
        repSummaries: [],
        capturedAt: Date()
    )

    func presentationSnapshot() -> QuickPoseResult {
        QuickPoseResult(
            schemaVersion: schemaVersion,
            stepResults: stepResults.map { $0.presentationSnapshot() },
            landmarks: [],
            jointAngles: jointAngles,
            romValues: romValues,
            asymmetryScores: asymmetryScores,
            movementQualityScores: movementQualityScores,
            gaitMetrics: gaitMetrics,
            repSummaries: repSummaries,
            capturedAt: capturedAt
        )
    }
}
