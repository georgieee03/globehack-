import SwiftUI

struct StreakView: View {
    let gamificationState: GamificationState
    let encouragementMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HydraEyebrow(text: "Momentum", icon: "flame.fill")

                    Text("\(gamificationState.streakDays)-day streak")
                        .font(HydraTypography.section(28))
                        .foregroundStyle(HydraTheme.Colors.primaryText)
                }

                Spacer()

                HydraBrandEmblem(size: 42)
            }

            HStack(spacing: 12) {
                statPill(title: "Level", value: "\(gamificationState.level)")
                statPill(title: "XP", value: "\(gamificationState.xp)")
            }

            Text(encouragementMessage)
                .font(HydraTypography.body(15))
                .foregroundStyle(HydraTheme.Colors.secondaryText)
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(HydraTypography.capsule())
                .foregroundStyle(HydraTheme.Colors.secondaryText)
                .tracking(0.6)
            Text(value)
                .font(HydraTypography.ui(18, weight: .semibold))
                .foregroundStyle(HydraTheme.Colors.primaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(HydraTheme.Colors.overlay)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(HydraTheme.Colors.stroke, lineWidth: 1)
                )
        )
    }
}

#Preview {
    StreakView(
        gamificationState: GamificationState(xp: 180, level: 2, streakDays: 4, lastActivityDate: Date()),
        encouragementMessage: "You are building steady momentum."
    )
    .padding()
}
