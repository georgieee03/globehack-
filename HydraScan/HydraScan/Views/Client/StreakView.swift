import SwiftUI

struct StreakView: View {
    let gamificationState: GamificationState
    let encouragementMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Momentum")
                        .font(.headline)
                    Text("\(gamificationState.streakDays)-day streak")
                        .font(.title3.weight(.semibold))
                }

                Spacer()

                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
            }

            Text("Level \(gamificationState.level) • \(gamificationState.xp) XP")
                .foregroundStyle(.secondary)

            Text(encouragementMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.orange.opacity(0.12))
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
