import Foundation

enum BodyRegion: String, Codable, CaseIterable, Hashable, Identifiable {
    case rightShoulder = "right_shoulder"
    case leftShoulder = "left_shoulder"
    case rightHip = "right_hip"
    case leftHip = "left_hip"
    case lowerBack = "lower_back"
    case upperBack = "upper_back"
    case rightKnee = "right_knee"
    case leftKnee = "left_knee"
    case neck
    case rightCalf = "right_calf"
    case leftCalf = "left_calf"
    case rightArm = "right_arm"
    case leftArm = "left_arm"
    case rightFoot = "right_foot"
    case leftFoot = "left_foot"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .rightShoulder: return "Right Shoulder"
        case .leftShoulder: return "Left Shoulder"
        case .rightHip: return "Right Hip"
        case .leftHip: return "Left Hip"
        case .lowerBack: return "Lower Back"
        case .upperBack: return "Upper Back"
        case .rightKnee: return "Right Knee"
        case .leftKnee: return "Left Knee"
        case .neck: return "Neck"
        case .rightCalf: return "Right Calf"
        case .leftCalf: return "Left Calf"
        case .rightArm: return "Right Arm"
        case .leftArm: return "Left Arm"
        case .rightFoot: return "Right Foot"
        case .leftFoot: return "Left Foot"
        }
    }
}

enum RecoveryGoal: String, Codable, CaseIterable, Hashable, Identifiable {
    case mobility
    case warmUp = "warm_up"
    case recovery
    case relaxation
    case performancePrep = "performance_prep"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .mobility: return "Improve Mobility"
        case .warmUp: return "Warm Up for Movement"
        case .recovery: return "Support Recovery"
        case .relaxation: return "Relax and Reset"
        case .performancePrep: return "Prepare for Performance"
        }
    }

    var detailText: String {
        switch self {
        case .mobility:
            return "Loosen up and move with more freedom."
        case .warmUp:
            return "Prime your body before training or activity."
        case .recovery:
            return "Settle down after effort and support your reset."
        case .relaxation:
            return "Reduce tension and create a calmer baseline."
        case .performancePrep:
            return "Get ready to move with confidence and control."
        }
    }
}

enum RecoverySignalType: String, Codable, CaseIterable, Hashable, Identifiable {
    case stiffness
    case soreness
    case tightness
    case restriction
    case guarding

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .stiffness: return "Stiffness"
        case .soreness: return "Soreness"
        case .tightness: return "Tightness"
        case .restriction: return "Restriction"
        case .guarding: return "Guarding"
        }
    }
}

enum ActivityTrigger: String, Codable, CaseIterable, Hashable, Identifiable {
    case morning
    case afterRunning = "after_running"
    case afterLifting = "after_lifting"
    case postTravel = "post_travel"
    case postTraining = "post_training"
    case evening
    case general

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .morning: return "Morning"
        case .afterRunning: return "After Running"
        case .afterLifting: return "After Lifting"
        case .postTravel: return "Post Travel"
        case .postTraining: return "Post Training"
        case .evening: return "Evening"
        case .general: return "General"
        }
    }
}

struct RecoverySignalValue: Codable, Hashable {
    var type: RecoverySignalType
    var severity: Int
    var trigger: String
    var notes: String?
}

struct RecoverySignal: Identifiable, Codable, Hashable {
    var id: String { region.rawValue }
    var region: BodyRegion
    var type: RecoverySignalType
    var severity: Int
    var trigger: String
    var notes: String?

    var value: RecoverySignalValue {
        RecoverySignalValue(type: type, severity: severity, trigger: trigger, notes: notes)
    }
}

enum TrendClassification: String, Codable, CaseIterable, Hashable {
    case improving
    case plateau
    case regressing
    case insufficientData = "insufficient_data"
}

struct NextVisitSignal: Codable, Hashable {
    var recommendedReturnDays: Int
    var urgency: String
    var rationale: String

    enum CodingKeys: String, CodingKey {
        case recommendedReturnDays = "recommended_return_days"
        case urgency
        case rationale
    }
}

struct ClientProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var clinicID: UUID?
    var primaryRegions: [BodyRegion]
    var recoverySignalsByRegion: [String: RecoverySignalValue]
    var goals: [RecoveryGoal]
    var activityContext: String?
    var sensitivities: [String]
    var notes: String?
    var wearableHRV: Double?
    var wearableStrain: Double?
    var wearableSleepScore: Double?
    var wearableLastSync: Date?
    var trendClassification: TrendClassification
    var needsAttention: Bool
    var nextVisitSignal: NextVisitSignal?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case clinicID = "clinic_id"
        case primaryRegions = "primary_regions"
        case recoverySignalsByRegion = "recovery_signals"
        case goals
        case activityContext = "activity_context"
        case sensitivities
        case notes
        case wearableHRV = "wearable_hrv"
        case wearableStrain = "wearable_strain"
        case wearableSleepScore = "wearable_sleep_score"
        case wearableLastSync = "wearable_last_sync"
        case trendClassification = "trend_classification"
        case needsAttention = "needs_attention"
        case nextVisitSignal = "next_visit_signal"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        userID: UUID,
        clinicID: UUID?,
        primaryRegions: [BodyRegion],
        recoverySignalsByRegion: [String: RecoverySignalValue],
        goals: [RecoveryGoal],
        activityContext: String?,
        sensitivities: [String],
        notes: String?,
        wearableHRV: Double?,
        wearableStrain: Double?,
        wearableSleepScore: Double?,
        wearableLastSync: Date?,
        trendClassification: TrendClassification = .insufficientData,
        needsAttention: Bool = false,
        nextVisitSignal: NextVisitSignal? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.clinicID = clinicID
        self.primaryRegions = primaryRegions
        self.recoverySignalsByRegion = recoverySignalsByRegion
        self.goals = goals
        self.activityContext = activityContext
        self.sensitivities = sensitivities
        self.notes = notes
        self.wearableHRV = wearableHRV
        self.wearableStrain = wearableStrain
        self.wearableSleepScore = wearableSleepScore
        self.wearableLastSync = wearableLastSync
        self.trendClassification = trendClassification
        self.needsAttention = needsAttention
        self.nextVisitSignal = nextVisitSignal
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var recoverySignals: [RecoverySignal] {
        primaryRegions.compactMap { region in
            guard let value = recoverySignalsByRegion[region.rawValue] else {
                return nil
            }

            return RecoverySignal(
                region: region,
                type: value.type,
                severity: value.severity,
                trigger: value.trigger,
                notes: value.notes
            )
        }
    }

    static let empty = ClientProfile(
        id: UUID(),
        userID: UUID(),
        clinicID: nil,
        primaryRegions: [],
        recoverySignalsByRegion: [:],
        goals: [],
        activityContext: nil,
        sensitivities: [],
        notes: nil,
        wearableHRV: nil,
        wearableStrain: nil,
        wearableSleepScore: nil,
        wearableLastSync: nil,
        trendClassification: .insufficientData,
        needsAttention: false,
        nextVisitSignal: nil,
        createdAt: Date(),
        updatedAt: Date()
    )

    static let preview = ClientProfile(
        id: UUID(),
        userID: UUID(),
        clinicID: UUID(),
        primaryRegions: [.lowerBack, .rightShoulder],
        recoverySignalsByRegion: [
            BodyRegion.lowerBack.rawValue: RecoverySignalValue(type: .tightness, severity: 6, trigger: ActivityTrigger.morning.rawValue, notes: "Noticed most after sitting"),
            BodyRegion.rightShoulder.rawValue: RecoverySignalValue(type: .stiffness, severity: 4, trigger: ActivityTrigger.postTraining.rawValue, notes: nil),
        ],
        goals: [.mobility],
        activityContext: "Desk-heavy day with a short lift in the evening.",
        sensitivities: [],
        notes: nil,
        wearableHRV: 54,
        wearableStrain: 31,
        wearableSleepScore: 82,
        wearableLastSync: Date(),
        trendClassification: .improving,
        needsAttention: false,
        nextVisitSignal: NextVisitSignal(
            recommendedReturnDays: 7,
            urgency: "routine",
            rationale: "Recovery momentum looks steady."
        ),
        createdAt: Date(),
        updatedAt: Date()
    )
}
