import SwiftUI

struct RecoveryScoreView: View {
    let recoveryScore: RecoveryScore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 20) {
                RecoveryScoreGauge(score: recoveryScore.current)

                VStack(alignment: .leading, spacing: 10) {
                    Text(recoveryScore.deltaDescription)
                        .font(.headline)
                        .foregroundStyle(recoveryScore.deltaFromLastWeek >= 0 ? .green : .orange)
                    Text("Updated \(recoveryScore.updatedAt.shortDateLabel)")
                        .foregroundStyle(.secondary)
                    Text("A higher score suggests your recent check-ins and sessions are trending in a healthier direction.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            TrendLineChart(points: recoveryScore.trend)
        }
    }
}

#Preview {
    RecoveryScoreView(
        recoveryScore: RecoveryScore(
            current: 82,
            deltaFromLastWeek: 6,
            updatedAt: Date(),
            trend: [
                RecoveryScoreTrendPoint(dayLabel: "Mon", value: 72),
                RecoveryScoreTrendPoint(dayLabel: "Tue", value: 74),
                RecoveryScoreTrendPoint(dayLabel: "Wed", value: 77),
                RecoveryScoreTrendPoint(dayLabel: "Thu", value: 79),
                RecoveryScoreTrendPoint(dayLabel: "Fri", value: 82),
            ]
        )
    )
    .padding()
}
