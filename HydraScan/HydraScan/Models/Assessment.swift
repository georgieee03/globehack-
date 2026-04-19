import Foundation

enum AssessmentType: String, Codable, CaseIterable, Hashable, Identifiable {
    case intake
    case preSession = "pre_session"
    case followUp = "follow_up"
    case reassessment

    var id: String { rawValue }
}

enum HydraJSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case object([String: HydraJSONValue])
    case array([HydraJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: HydraJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([HydraJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .integer(value):
            try container.encode(value)
        case let .boolean(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct SubjectiveBaseline: Codable, Hashable {
    var stiffness: Int?
    var soreness: Int?
    var notes: String?
}

enum HydraSessionStatus: String, Codable, CaseIterable, Hashable, Identifiable {
    case pending
    case active
    case paused
    case completed
    case cancelled
    case error

    var id: String { rawValue }
}

struct HydraSession: Identifiable, Codable, Hashable {
    var id: UUID
    var clientID: UUID
    var clinicID: UUID
    var practitionerID: UUID
    var deviceID: UUID
    var assessmentID: UUID?
    var sessionConfig: [String: HydraJSONValue]
    var recommendedConfig: [String: HydraJSONValue]?
    var practitionerEdits: [String: HydraJSONValue]?
    var recommendationRationale: String?
    var confidenceScore: Double?
    var status: HydraSessionStatus
    var startedAt: Date?
    var pausedAt: Date?
    var resumedAt: Date?
    var completedAt: Date?
    var totalDurationSeconds: Int?
    var outcome: [String: HydraJSONValue]?
    var practitionerNotes: String?
    var retestValues: [String: HydraJSONValue]?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case clinicID = "clinic_id"
        case practitionerID = "practitioner_id"
        case deviceID = "device_id"
        case assessmentID = "assessment_id"
        case sessionConfig = "session_config"
        case recommendedConfig = "recommended_config"
        case practitionerEdits = "practitioner_edits"
        case recommendationRationale = "recommendation_rationale"
        case confidenceScore = "confidence_score"
        case status
        case startedAt = "started_at"
        case pausedAt = "paused_at"
        case resumedAt = "resumed_at"
        case completedAt = "completed_at"
        case totalDurationSeconds = "total_duration_s"
        case outcome
        case practitionerNotes = "practitioner_notes"
        case retestValues = "retest_values"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct HydraSessionAwareness: Codable, Hashable {
    var activeSession: HydraSession?
    var latestSession: HydraSession?
    var updatedAt: Date
}

struct Assessment: Identifiable, Codable, Hashable {
    var id: UUID
    var clientID: UUID
    var clinicID: UUID?
    var practitionerID: UUID?
    var assessmentType: AssessmentType
    var quickPoseData: QuickPoseResult?
    var romValues: [String: Double]
    var asymmetryScores: [String: Double]
    var movementQualityScores: [String: Double]
    var gaitMetrics: [String: Double]
    var heartRate: Double?
    var breathRate: Double?
    var hrvRMSSD: Double?
    var bodyZones: [BodyRegion]
    var recoveryGoal: RecoveryGoal?
    var subjectiveBaseline: SubjectiveBaseline?
    var recoveryMap: RecoveryMap?
    var recoveryGraphDelta: [String: Double]
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case clinicID = "clinic_id"
        case practitionerID = "practitioner_id"
        case assessmentType = "assessment_type"
        case quickPoseData = "quickpose_data"
        case romValues = "rom_values"
        case asymmetryScores = "asymmetry_scores"
        case movementQualityScores = "movement_quality_scores"
        case gaitMetrics = "gait_metrics"
        case heartRate = "heart_rate"
        case breathRate = "breath_rate"
        case hrvRMSSD = "hrv_rmssd"
        case bodyZones = "body_zones"
        case recoveryGoal = "recovery_goal"
        case subjectiveBaseline = "subjective_baseline"
        case recoveryMap = "recovery_map"
        case recoveryGraphDelta = "recovery_graph_delta"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        clientID: UUID,
        clinicID: UUID?,
        practitionerID: UUID?,
        assessmentType: AssessmentType,
        quickPoseData: QuickPoseResult?,
        romValues: [String: Double],
        asymmetryScores: [String: Double],
        movementQualityScores: [String: Double],
        gaitMetrics: [String: Double],
        heartRate: Double?,
        breathRate: Double?,
        hrvRMSSD: Double?,
        bodyZones: [BodyRegion],
        recoveryGoal: RecoveryGoal?,
        subjectiveBaseline: SubjectiveBaseline?,
        recoveryMap: RecoveryMap?,
        recoveryGraphDelta: [String: Double],
        createdAt: Date
    ) {
        self.id = id
        self.clientID = clientID
        self.clinicID = clinicID
        self.practitionerID = practitionerID
        self.assessmentType = assessmentType
        self.quickPoseData = quickPoseData
        self.romValues = romValues
        self.asymmetryScores = asymmetryScores
        self.movementQualityScores = movementQualityScores
        self.gaitMetrics = gaitMetrics
        self.heartRate = heartRate
        self.breathRate = breathRate
        self.hrvRMSSD = hrvRMSSD
        self.bodyZones = bodyZones
        self.recoveryGoal = recoveryGoal
        self.subjectiveBaseline = subjectiveBaseline
        self.recoveryMap = recoveryMap
        self.recoveryGraphDelta = recoveryGraphDelta
        self.createdAt = createdAt
    }

    static let preview = Assessment(
        id: UUID(),
        clientID: UUID(),
        clinicID: UUID(),
        practitionerID: nil,
        assessmentType: .intake,
        quickPoseData: .empty,
        romValues: [:],
        asymmetryScores: [:],
        movementQualityScores: [:],
        gaitMetrics: [:],
        heartRate: nil,
        breathRate: nil,
        hrvRMSSD: nil,
        bodyZones: [],
        recoveryGoal: .mobility,
        subjectiveBaseline: nil,
        recoveryMap: nil,
        recoveryGraphDelta: [:],
        createdAt: Date()
    )
}
