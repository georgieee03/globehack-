import SwiftUI

struct GoalPickerView: View {
    @ObservedObject var viewModel: IntakeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose the outcome you want this session to support.")
                .foregroundStyle(.secondary)

            ForEach(RecoveryGoal.allCases) { goal in
                Button {
                    viewModel.recoveryGoal = goal
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: viewModel.recoveryGoal == goal ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.recoveryGoal == goal ? .teal : .secondary)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(goal.displayLabel)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(goal.detailText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(viewModel.recoveryGoal == goal ? Color.teal.opacity(0.12) : Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    GoalPickerView(viewModel: IntakeViewModel(user: .preview, service: MockInsforgeService.shared))
        .padding()
}
