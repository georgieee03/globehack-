import Foundation

protocol GamificationServiceProtocol {
    func buildState(
        assessments: [Assessment],
        outcomes: [Outcome],
        checkins: [DailyCheckin]
    ) -> GamificationState
    func encouragement(for streakDays: Int) -> String
}

struct GamificationService: GamificationServiceProtocol {
    func buildState(
        assessments: [Assessment],
        outcomes: [Outcome],
        checkins: [DailyCheckin]
    ) -> GamificationState {
        let assessmentXP = assessments.count * (HydraScanConstants.xpRewards[.assessmentCompleted] ?? 0)
        let checkinXP = checkins.count * (HydraScanConstants.xpRewards[.dailyCheckIn] ?? 0)
        let feedbackXP = outcomes.count * (HydraScanConstants.xpRewards[.postSessionFeedback] ?? 0)
        let streakDays = Self.computeStreak(from: assessments, checkins: checkins)
        let streakBonus = streakDays >= 7 ? (HydraScanConstants.xpRewards[.streakBonus] ?? 0) * (streakDays / 7) : 0
        let totalXP = assessmentXP + checkinXP + feedbackXP + streakBonus

        return GamificationState(
            xp: totalXP,
            level: Self.level(for: totalXP),
            streakDays: streakDays,
            lastActivityDate: Self.latestActivityDate(from: assessments, outcomes: outcomes, checkins: checkins)
        )
    }

    func encouragement(for streakDays: Int) -> String {
        switch streakDays {
        case 0:
            return "Every reset starts with one quick check-in."
        case 1..<7:
            return "You are building steady momentum."
        case 7..<30:
            return "Your recovery rhythm is taking shape."
        default:
            return "That consistency is paying off in a big way."
        }
    }

    private static func computeStreak(from assessments: [Assessment], checkins: [DailyCheckin]) -> Int {
        let calendar = Calendar.current
        let dates = Set(
            assessments.map(\.createdAt) + checkins.map(\.createdAt)
        )
        .map { calendar.startOfDay(for: $0) }
        .sorted(by: >)

        guard let first = dates.first else { return 0 }
        var streak = 1
        var expected = first

        for date in dates.dropFirst() {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: expected) else {
                break
            }

            if calendar.isDate(date, inSameDayAs: previousDay) {
                streak += 1
                expected = date
            } else if date < previousDay {
                break
            }
        }

        if let lastLoggedDay = dates.first {
            let today = calendar.startOfDay(for: Date())
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            if !calendar.isDate(lastLoggedDay, inSameDayAs: today) &&
                !(yesterday.map { calendar.isDate(lastLoggedDay, inSameDayAs: $0) } ?? false) {
                return 0
            }
        }

        return streak
    }

    private static func level(for xp: Int) -> Int {
        HydraScanConstants.levelThresholds
            .sorted { $0.key < $1.key }
            .last(where: { xp >= $0.value })?
            .key ?? 1
    }

    private static func latestActivityDate(
        from assessments: [Assessment],
        outcomes: [Outcome],
        checkins: [DailyCheckin]
    ) -> Date? {
        (assessments.map(\.createdAt) + outcomes.map(\.createdAt) + checkins.map(\.createdAt))
            .max()
    }
}
