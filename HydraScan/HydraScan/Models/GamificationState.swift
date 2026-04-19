import Foundation

struct GamificationState: Codable, Hashable {
    var xp: Int
    var level: Int
    var streakDays: Int
    var lastActivityDate: Date?

    static var levelThresholds: [Int: Int] {
        HydraScanConstants.levelThresholds
    }

    static var xpRewards: [XPRewardEvent: Int] {
        HydraScanConstants.xpRewards
    }
}
