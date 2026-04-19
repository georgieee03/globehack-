import SwiftUI

struct GoalPickerView: View {
    @ObservedObject var viewModel: IntakeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose the outcome you want this session to support.")
                .font(HydraTypography.body(16))
                .foregroundStyle(HydraTheme.Colors.secondaryText)

            ForEach(RecoveryGoal.allCases) { goal in
                Button {
                    viewModel.recoveryGoal = goal
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: viewModel.recoveryGoal == goal ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.recoveryGoal == goal ? HydraTheme.Colors.goldDeep : HydraTheme.Colors.secondaryText)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(goal.displayLabel)
                                .font(HydraTypography.section(24))
                                .foregroundStyle(HydraTheme.Colors.primaryText)
                            Text(goal.detailText)
                                .font(HydraTypography.body(15))
                                .foregroundStyle(HydraTheme.Colors.secondaryText)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(goalBackgroundFill(isSelected: viewModel.recoveryGoal == goal))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(
                                        viewModel.recoveryGoal == goal
                                            ? HydraTheme.Colors.goldOutline.opacity(0.55)
                                            : HydraTheme.Colors.stroke,
                                        lineWidth: 1
                                    )
                            )
                    )
                    .foregroundStyle(viewModel.recoveryGoal == goal ? HydraTheme.Colors.ink : HydraTheme.Colors.primaryText)
                    .overlay(alignment: .topTrailing) {
                        if viewModel.recoveryGoal == goal {
                            HydraEyebrow(text: "Selected")
                                .scaleEffect(0.82)
                                .padding(12)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func goalBackgroundFill(isSelected: Bool) -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [HydraTheme.Colors.goldSoft.opacity(0.95), HydraTheme.Colors.gold.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return HydraTheme.fill(for: .panel)
    }
}

#Preview {
    GoalPickerView(viewModel: IntakeViewModel(user: .preview, service: MockSupabaseService.shared))
        .padding()
}
