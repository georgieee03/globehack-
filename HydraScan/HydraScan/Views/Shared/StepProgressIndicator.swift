import SwiftUI

struct StepProgressIndicator: View {
    let title: String
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HydraEyebrow(text: title)
                Spacer()
                Text("\(currentStep)/\(totalSteps)")
                    .font(HydraTypography.ui(14, weight: .semibold))
                    .foregroundStyle(HydraTheme.Colors.secondaryText)
            }

            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(
                            index < currentStep
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [HydraTheme.Colors.goldSoft, HydraTheme.Colors.gold],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(HydraTheme.Colors.stroke)
                        )
                        .frame(height: 10)
                }
            }
        }
    }
}

#Preview {
    StepProgressIndicator(title: "Capture Progress", currentStep: 3, totalSteps: 7)
        .padding()
}
