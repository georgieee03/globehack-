import SwiftUI

struct RecoveryScoreView: View {
    let recoveryScore: RecoveryScore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 20) {
                RecoveryScoreGauge(score: recoveryScore.current)

                VStack(alignment: .leading, spacing: 10) {
                    HydraEyebrow(text: "Recovery Score", icon: "waveform.path.ecg")

                    Text(recoveryScore.deltaDescription)
                        .font(HydraTypography.section(26))
                        .foregroundStyle(recoveryScore.deltaFromLastWeek >= 0 ? HydraTheme.Colors.success : HydraTheme.Colors.warning)
                    Text("Updated \(recoveryScore.updatedAt.shortDateLabel)")
                        .font(HydraTypography.body(14, weight: .medium))
                        .foregroundStyle(HydraTheme.Colors.secondaryText)
                    Text("A higher score suggests your recent check-ins and sessions are trending in a healthier direction.")
                        .font(HydraTypography.body(15))
                        .foregroundStyle(HydraTheme.Colors.secondaryText)
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
