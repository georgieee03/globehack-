import Foundation

enum ExerciseSymptom: String, Codable, CaseIterable, Hashable, Identifiable {
    case stiffness
    case soreness
    case tightness
    case restriction
    case guarding
    case postActivityDiscomfort = "post_activity_discomfort"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .stiffness:
            return "Stiffness"
        case .soreness:
            return "Soreness"
        case .tightness:
            return "Tightness"
        case .restriction:
            return "Restriction"
        case .guarding:
            return "Guarding"
        case .postActivityDiscomfort:
            return "Post-Activity Discomfort"
        }
    }
}

enum ContentHost: String, Codable, Hashable {
    case youtube
    case professionalPlatform = "professional_platform"
}

enum PlaybackMode: String, Codable, Hashable {
    case inAppBrowser = "in_app_browser"
    case embeddedWeb = "embedded_web"
    case externalBrowser = "external_browser"
}

enum SourceQualityTier: String, Codable, Hashable {
    case academicMedical = "academic_medical"
    case ptReviewedPlatform = "pt_reviewed_platform"
    case licensedPtCreator = "licensed_pt_creator"
    case fitnessEducator = "fitness_educator"
}

enum ReviewStatus: String, Codable, Hashable {
    case pendingReview = "pending_review"
    case approved
    case rejected
    case archived
}

enum PlanStatus: String, Codable, Hashable {
    case active
    case superseded
    case pausedForSafety = "paused_for_safety"
    case completed
    case archived

    var displayLabel: String {
        switch self {
        case .active:
            return "Active"
        case .superseded:
            return "Superseded"
        case .pausedForSafety:
            return "Paused for Safety"
        case .completed:
            return "Completed"
        case .archived:
            return "Archived"
        }
    }
}

enum PlanRefreshReason: String, Codable, Hashable {
    case initialIntake = "initial_intake"
    case goalChange = "goal_change"
    case signalChange = "signal_change"
    case assessmentChange = "assessment_change"
    case stalePlan = "stale_plan"
    case manualRefresh = "manual_refresh"

    var displayLabel: String {
        switch self {
        case .initialIntake:
            return "Initial Intake"
        case .goalChange:
            return "Goal Change"
        case .signalChange:
            return "Signal Change"
        case .assessmentChange:
            return "Assessment Change"
        case .stalePlan:
            return "Stale Plan Refresh"
        case .manualRefresh:
            return "Manual Refresh"
        }
    }
}

enum RecoveryPlanRefreshDecision: String, Codable, Hashable {
    case initialIntake = "initial_intake"
    case goalChange = "goal_change"
    case signalChange = "signal_change"
    case assessmentChange = "assessment_change"
    case stalePlan = "stale_plan"
    case manualRefresh = "manual_refresh"
    case noChange = "no_change"
    case noPlanAvailable = "no_plan_available"

    var displayLabel: String {
        switch self {
        case .initialIntake:
            return "Initial intake plan created."
        case .goalChange:
            return "Plan refreshed because your goals changed."
        case .signalChange:
            return "Plan refreshed because your recovery signals changed."
        case .assessmentChange:
            return "Plan refreshed from your latest assessment."
        case .stalePlan:
            return "Plan refreshed because the previous plan was stale."
        case .manualRefresh:
            return "Plan manually refreshed."
        case .noChange:
            return "Your current plan is already up to date."
        case .noPlanAvailable:
            return "No approved recovery plan could be generated yet."
        }
    }
}

enum PlanCadence: String, Codable, Hashable {
    case daily
    case postActivity = "post_activity"
    case morning
    case evening

    var displayLabel: String {
        switch self {
        case .daily:
            return "Daily"
        case .postActivity:
            return "Post-Activity"
        case .morning:
            return "Morning"
        case .evening:
            return "Evening"
        }
    }
}

enum RecoveryPlanItemRole: String, Codable, Hashable {
    case required
    case optionalSupport = "optional_support"

    var displayLabel: String {
        switch self {
        case .required:
            return "Required"
        case .optionalSupport:
            return "Optional Support"
        }
    }
}

enum CompletionStatus: String, Codable, Hashable, CaseIterable, Identifiable {
    case started
    case completed
    case skipped
    case stopped

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .started:
            return "Started"
        case .completed:
            return "Completed"
        case .skipped:
            return "Skipped"
        case .stopped:
            return "Stopped"
        }
    }
}

enum SymptomResponse: String, Codable, Hashable, CaseIterable, Identifiable {
    case better
    case same
    case worse

    var id: String { rawValue }

    var displayLabel: String {
        rawValue.capitalized
    }
}

struct HydrawavPairing: Codable, Hashable {
    var sunPad: String
    var moonPad: String
    var intensity: String
    var durationMin: Int
    var practitionerNote: String?

    enum CodingKeys: String, CodingKey {
        case sunPad = "sun_pad"
        case moonPad = "moon_pad"
        case intensity
        case durationMin = "duration_min"
        case practitionerNote = "practitioner_note"
    }

    var durationLabel: String {
        "\(durationMin) min"
    }

    var intensityLabel: String {
        intensity
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

struct ExerciseVideo: Identifiable, Codable, Hashable {
    var id: String
    var canonicalURL: URL
    var thumbnailURL: URL?
    var playbackMode: PlaybackMode
    var contentHost: ContentHost
    var title: String
    var creatorName: String
    var creatorCredentials: String
    var sourceQualityTier: SourceQualityTier
    var language: String
    var durationSeconds: Int?
    var bodyRegions: [BodyRegion]
    var symptomTags: [ExerciseSymptom]
    var movementTags: [String]
    var goalTags: [RecoveryGoal]
    var equipmentTags: [String]
    var activityTriggerTags: [ActivityTrigger]
    var level: String?
    var contraindicationTags: [String]
    var practitionerNotes: String?
    var hydrawavPairing: HydrawavPairing?
    var qualityScore: Double
    var confidenceScore: Double
    var humanReviewStatus: ReviewStatus
    var lastReviewedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case canonicalURL = "canonical_url"
        case thumbnailURL = "thumbnail_url"
        case playbackMode = "playback_mode"
        case contentHost = "content_host"
        case title
        case creatorName = "creator_name"
        case creatorCredentials = "creator_credentials"
        case sourceQualityTier = "source_quality_tier"
        case language
        case durationSeconds = "duration_sec"
        case bodyRegions = "body_regions"
        case symptomTags = "symptom_tags"
        case movementTags = "movement_tags"
        case goalTags = "goal_tags"
        case equipmentTags = "equipment_tags"
        case activityTriggerTags = "activity_trigger_tags"
        case level
        case contraindicationTags = "contraindication_tags"
        case practitionerNotes = "practitioner_notes"
        case hydrawavPairing = "hydrawav_pairing"
        case qualityScore = "quality_score"
        case confidenceScore = "confidence_score"
        case humanReviewStatus = "human_review_status"
        case lastReviewedAt = "last_reviewed_at"
    }

    var hostLabel: String {
        switch contentHost {
        case .youtube:
            return "YouTube"
        case .professionalPlatform:
            return "Professional Platform"
        }
    }
}

struct RecoveryPlanProgressSummary: Codable, Hashable {
    var completedThisWeek: Int
    var assignedThisWeek: Int
    var totalItems: Int
    var requiredItems: Int
    var optionalItems: Int
    var completionRate: Double
    var latestCompletionAt: Date?
    var pausedForSafety: Bool

    enum CodingKeys: String, CodingKey {
        case completedThisWeek = "completed_this_week"
        case assignedThisWeek = "assigned_this_week"
        case totalItems = "total_items"
        case requiredItems = "required_items"
        case optionalItems = "optional_items"
        case completionRate = "completion_rate"
        case latestCompletionAt = "latest_completion_at"
        case pausedForSafety = "paused_for_safety"
    }

    var completionPercentLabel: String {
        "\(Int((completionRate * 100).rounded()))%"
    }
}

struct RecoveryPlanCompletionLog: Identifiable, Codable, Hashable {
    var id: UUID
    var planID: UUID
    var planItemID: UUID
    var status: CompletionStatus
    var toleranceRating: Int?
    var difficultyRating: Int?
    var symptomResponse: SymptomResponse?
    var notes: String?
    var startedAt: Date?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case planID = "plan_id"
        case planItemID = "plan_item_id"
        case status
        case toleranceRating = "tolerance_rating"
        case difficultyRating = "difficulty_rating"
        case symptomResponse = "symptom_response"
        case notes
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var primaryTimestamp: Date {
        completedAt ?? startedAt ?? createdAt
    }
}

struct RecoveryPlanItem: Identifiable, Codable, Hashable {
    var id: UUID
    var planID: UUID
    var position: Int
    var itemRole: RecoveryPlanItemRole
    var region: BodyRegion
    var symptom: ExerciseSymptom
    var cadence: PlanCadence
    var weeklyTargetCount: Int
    var rationale: String
    var displayNotes: String?
    var hydrawavPairing: HydrawavPairing
    var video: ExerciseVideo

    enum CodingKeys: String, CodingKey {
        case id
        case planID = "plan_id"
        case position
        case itemRole = "item_role"
        case region
        case symptom
        case cadence
        case weeklyTargetCount = "weekly_target_count"
        case rationale
        case displayNotes = "display_notes"
        case hydrawavPairing = "hydrawav_pairing"
        case video
    }
}

struct RecoveryPlan: Identifiable, Codable, Hashable {
    var id: UUID
    var clientID: UUID
    var clinicID: UUID
    var status: PlanStatus
    var refreshReason: PlanRefreshReason
    var sourceAssessmentID: UUID?
    var summary: String
    var activityContext: String?
    var primaryRegions: [BodyRegion]
    var recoverySignals: [RecoverySignal]
    var goals: [RecoveryGoal]
    var safetyPauseReason: String?
    var pausedForSafetyAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var items: [RecoveryPlanItem]
    var recentCompletionLogs: [RecoveryPlanCompletionLog]
    var progress: RecoveryPlanProgressSummary

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case clinicID = "clinic_id"
        case status
        case refreshReason = "refresh_reason"
        case sourceAssessmentID = "source_assessment_id"
        case summary
        case activityContext = "activity_context"
        case primaryRegions = "primary_regions"
        case recoverySignals = "recovery_signals"
        case goals
        case safetyPauseReason = "safety_pause_reason"
        case pausedForSafetyAt = "paused_for_safety_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case items
        case recentCompletionLogs = "recent_completion_logs"
        case progress
    }

    var requiredItems: [RecoveryPlanItem] {
        items
            .filter { $0.itemRole == .required }
            .sorted { $0.position < $1.position }
    }

    var optionalSupportItems: [RecoveryPlanItem] {
        items
            .filter { $0.itemRole == .optionalSupport }
            .sorted { $0.position < $1.position }
    }

    var sortedRecentLogs: [RecoveryPlanCompletionLog] {
        recentCompletionLogs.sorted { $0.primaryTimestamp > $1.primaryTimestamp }
    }

    func latestStatus(for item: RecoveryPlanItem) -> CompletionStatus? {
        sortedRecentLogs.first(where: { $0.planItemID == item.id })?.status
    }

    var nextSuggestedItem: RecoveryPlanItem? {
        requiredItems.first(where: { latestStatus(for: $0) != .completed })
            ?? items.sorted(by: { $0.position < $1.position }).first
    }

    var isPausedForSafety: Bool {
        status == .pausedForSafety || progress.pausedForSafety
    }
}

struct RecoveryPlanHistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var status: PlanStatus
    var refreshReason: PlanRefreshReason
    var sourceAssessmentID: UUID?
    var summary: String
    var createdAt: Date
    var updatedAt: Date
    var supersededAt: Date?
    var completionRate: Double
    var itemCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case refreshReason = "refresh_reason"
        case sourceAssessmentID = "source_assessment_id"
        case summary
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case supersededAt = "superseded_at"
        case completionRate = "completion_rate"
        case itemCount = "item_count"
    }
}

struct RecoveryPlanRefreshResult: Codable, Hashable {
    var refreshed: Bool
    var reason: RecoveryPlanRefreshDecision
    var plan: RecoveryPlan?
}
