import Foundation

enum RecoveryMapTrend: String, Codable, Hashable {
    case improving
    case declining
    case stable
}

struct HighlightedRegion: Identifiable, Codable, Hashable {
    var id: String { region.rawValue }
    var region: BodyRegion
    var severity: Int
    var signalType: RecoverySignalType
    var romDelta: Double?
    var trend: RecoveryMapTrend?
    var asymmetryFlag: Bool
    var compensationHint: String?

    enum CodingKeys: String, CodingKey {
        case region
        case severity
        case signalType = "signalType"
        case romDelta = "romDelta"
        case trend
        case asymmetryFlag = "asymmetryFlag"
        case compensationHint = "compensationHint"
    }
}

struct WearableContext: Codable, Hashable {
    var hrv: Double?
    var strain: Double?
    var sleepScore: Double?
    var lastSync: Date?

    enum CodingKeys: String, CodingKey {
        case hrv
        case strain
        case sleepScore = "sleepScore"
        case lastSync = "lastSync"
    }
}

struct PriorSessionSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var configSummary: String
    var outcomeRating: Double?

    enum CodingKeys: String, CodingKey {
        case date
        case configSummary = "configSummary"
        case outcomeRating = "outcomeRating"
    }

    var configurationSummary: String {
        configSummary
    }
}

struct RecoveryMap: Codable, Hashable {
    var clientID: UUID?
    var highlightedRegions: [HighlightedRegion]
    var wearableContext: WearableContext?
    var priorSessions: [PriorSessionSummary]
    var suggestedGoal: RecoveryGoal?
    var generatedAt: Date

    enum CodingKeys: String, CodingKey {
        case clientID = "clientId"
        case highlightedRegions = "highlightedRegions"
        case wearableContext = "wearableContext"
        case priorSessions = "priorSessions"
        case suggestedGoal = "suggestedGoal"
        case generatedAt = "generatedAt"
    }
}
