import SwiftUI

struct RecoveryScoreGauge: View {
    let score: Int

    private var progress: Double {
        Double(max(0, min(100, score))) / 100
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(HydraTheme.Colors.stroke, lineWidth: 18)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [HydraTheme.Colors.goldSoft, HydraTheme.Colors.gold, HydraTheme.Colors.goldDeep],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Text("\(score)")
                    .font(HydraTypography.numeric(40))
                    .foregroundStyle(HydraTheme.Colors.primaryText)
                Text("Recovery Score")
                    .font(HydraTypography.capsule())
                    .tracking(0.6)
                    .foregroundStyle(HydraTheme.Colors.secondaryText)
            }
        }
        .frame(width: 180, height: 180)
    }
}

#Preview {
    RecoveryScoreGauge(score: 82)
        .padding()
}
