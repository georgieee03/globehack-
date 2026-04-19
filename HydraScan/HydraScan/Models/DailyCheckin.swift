import Foundation

enum CheckinType: String, Codable, CaseIterable, Hashable, Identifiable {
    case daily
    case postActivity = "post_activity"
    case preVisit = "pre_visit"

    var id: String { rawValue }
}

struct DailyCheckin: Identifiable, Codable, Hashable {
    var id: UUID
    var clientID: UUID
    var clinicID: UUID?
    var checkinType: CheckinType
    var overallFeeling: Int
    var targetRegions: [BodyRegion]
    var activitySinceLast: String?
    var recoveryScore: Double?
    var createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case clinicID = "clinic_id"
        case checkinType = "checkin_type"
        case overallFeeling = "overall_feeling"
        case targetRegions = "target_regions"
        case activitySinceLast = "activity_since_last"
        case recoveryScore = "recovery_score"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        clientID: UUID,
        clinicID: UUID?,
        checkinType: CheckinType,
        overallFeeling: Int,
        targetRegions: [BodyRegion],
        activitySinceLast: String?,
        recoveryScore: Double?,
        createdAt: Date,
        updatedAt: Date?
    ) {
        self.id = id
        self.clientID = clientID
        self.clinicID = clinicID
        self.checkinType = checkinType
        self.overallFeeling = overallFeeling
        self.targetRegions = targetRegions
        self.activitySinceLast = activitySinceLast
        self.recoveryScore = recoveryScore
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
