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
}
