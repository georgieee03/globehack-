import SwiftUI

struct PostSessionView: View {
    @StateObject private var viewModel: FeedbackViewModel
    let onSubmitted: () -> Void

    init(user: HydraUser, assessment: Assessment, service: SupabaseServiceProtocol, onSubmitted: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(user: user, assessment: assessment, service: service))
        self.onSubmitted = onSubmitted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HydraSectionHeader(
                    eyebrow: "Post-Session Feedback",
                    title: "Close the loop on this session.",
                    subtitle: "A short reflection keeps your recovery score and practitioner-facing outcome summary accurate."
                )

                HydraCard(role: .ivory) {
                    Text("Session Reflection")
                        .font(HydraTypography.section(28))
                        .foregroundStyle(HydraTheme.Colors.ink)

                    HydraMetricRow(
                        label: "Focus",
                        value: viewModel.assessment.bodyZones.isEmpty
                            ? "General movement scan"
                            : viewModel.assessment.bodyZones.map(\.displayLabel).joined(separator: ", "),
                        accent: HydraTheme.Colors.ink,
                        labelWidth: 90
                    )

                    HydraMetricRow(
                        label: "Goal",
                        value: viewModel.assessment.recoveryGoal?.displayLabel ?? "General recovery",
                        accent: HydraTheme.Colors.ink,
                        labelWidth: 90
                    )
                }

                sliderCard(title: "Stiffness After", value: $viewModel.stiffnessAfter)
                sliderCard(title: "Soreness After", value: $viewModel.sorenessAfter)

                triStatePicker(title: "Did mobility feel better?", selection: $viewModel.mobilityImproved)
                triStatePicker(title: "Did this session feel effective?", selection: $viewModel.sessionEffective)
                triStatePicker(title: "Do you feel more ready to move?", selection: $viewModel.readinessImproved)

                HydraCard(role: .panel) {
                    Text("Would you repeat this flow?")
                        .font(HydraTypography.ui(15, weight: .semibold))
                        .foregroundStyle(HydraTheme.Colors.primaryText)

                    ChoiceFlow(spacing: 10, lineSpacing: 10) {
                        ForEach(RepeatIntent.allCases.filter { $0 != .noTryDifferent }) { option in
                            Button(option.uiLabel) {
                                viewModel.repeatIntent = option
                            }
                            .buttonStyle(HydraChipStyle(selected: viewModel.repeatIntent == option, emphasized: true))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Notes")
                        .font(HydraTypography.ui(15, weight: .semibold))
                        .foregroundStyle(HydraTheme.Colors.primaryText)
                    HydraInputShell {
                        TextEditor(text: $viewModel.clientNotes)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .font(HydraTypography.body(16))
                            .foregroundStyle(HydraTheme.Colors.primaryText)
                            .background(Color.clear)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    HydraStatusBanner(message: errorMessage, tone: .error, icon: "exclamationmark.triangle.fill")
                }

                if viewModel.isSaving {
                    HydraStatusBanner(
                        message: "Submitting your client-side outcome summary to HydraScan…",
                        tone: .neutral,
                        icon: "arrow.triangle.2.circlepath.circle.fill"
                    )
                }

                Button("Submit Feedback") {
                    Task {
                        if await viewModel.submit() != nil {
                            onSubmitted()
                        }
                    }
                }
                .buttonStyle(HydraButtonStyle(kind: .primary))
                .disabled(viewModel.isSaving)
            }
            .padding(.vertical, 12)
        }
    }

    private func sliderCard(title: String, value: Binding<Double>) -> some View {
        HydraCard(role: .panel) {
            HStack {
                Text(title)
                    .font(HydraTypography.section(24))
                    .foregroundStyle(HydraTheme.Colors.primaryText)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))/10")
                    .font(HydraTypography.ui(15, weight: .semibold))
                    .foregroundStyle(HydraTheme.Colors.secondaryText)
            }

            Slider(value: value, in: 0...10, step: 1)
        }
    }

    private func triStatePicker(title: String, selection: Binding<TriStateChoice>) -> some View {
        HydraCard(role: .panel) {
            Text(title)
                .font(HydraTypography.ui(15, weight: .semibold))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            ChoiceFlow(spacing: 10, lineSpacing: 10) {
                ForEach(TriStateChoice.allCases) { option in
                    Button(option.uiLabel) {
                        selection.wrappedValue = option
                    }
                    .buttonStyle(HydraChipStyle(selected: selection.wrappedValue == option, emphasized: true))
                }
            }
        }
    }
}

private struct ChoiceFlow<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        FlowLayout(spacing: spacing, lineSpacing: lineSpacing) {
            content
        }
    }
}

private extension TriStateChoice {
    var uiLabel: String {
        rawValue.capitalized
    }
}

private extension RepeatIntent {
    var uiLabel: String {
        switch self {
        case .yes:
            return "Yes"
        case .maybe:
            return "Maybe"
        case .no:
            return "No"
        case .noTryDifferent:
            return "No, Try Different"
        }
    }
}

#Preview {
    PostSessionView(user: .preview, assessment: .preview, service: MockSupabaseService.shared) {}
        .padding()
}
