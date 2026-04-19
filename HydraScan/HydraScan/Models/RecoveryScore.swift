import Foundation

struct RecoveryScoreTrendPoint: Identifiable, Codable, Hashable {
    var id = UUID()
    var dayLabel: String
    var value: Int
}

struct RecoveryScore: Codable, Hashable {
    var current: Int
    var deltaFromLastWeek: Int
    var updatedAt: Date
    var trend: [RecoveryScoreTrendPoint]

    var deltaDescription: String {
        let direction = deltaFromLastWeek >= 0 ? "+" : ""
        return "\(direction)\(deltaFromLastWeek) compared with last week"
    }
}
