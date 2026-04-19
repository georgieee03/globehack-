import SwiftUI

struct RecoveryScoreGauge: View {
    let score: Int

    private var progress: Double {
        Double(max(0, min(100, score))) / 100
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.teal.opacity(0.12), lineWidth: 18)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.mint, .teal, .cyan],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Text("\(score)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Recovery Score")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
    }
}

#Preview {
    RecoveryScoreGauge(score: 82)
        .padding()
}
