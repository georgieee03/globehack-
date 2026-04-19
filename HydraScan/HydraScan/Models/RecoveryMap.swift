import Foundation

struct HighlightedRegion: Identifiable, Codable, Hashable {
    var id = UUID()
    var region: BodyRegion
    var severity: Int
    var signalType: RecoverySignalType
    var romDelta: Double?
    var asymmetryFlag: Bool
    var compensationHint: String?
}

struct WearableContext: Codable, Hashable {
    var hrv: Double?
    var strain: Double?
    var sleepScore: Double?
    var lastSync: Date?
}

struct PriorSessionSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var configurationSummary: String
    var outcomeRating: String?
}

struct RecoveryMap: Codable, Hashable {
    var highlightedRegions: [HighlightedRegion]
    var wearableContext: WearableContext?
    var priorSessions: [PriorSessionSummary]
    var suggestedGoal: RecoveryGoal?
    var generatedAt: Date
}
