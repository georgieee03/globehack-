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

                sliderCard(title: "Stiffness After", value: $viewModel.stiffnessAfter)
                sliderCard(title: "Soreness After", value: $viewModel.sorenessAfter)

                triStatePicker(title: "Did mobility feel better?", selection: $viewModel.mobilityImproved)
                triStatePicker(title: "Did this session feel effective?", selection: $viewModel.sessionEffective)
                triStatePicker(title: "Do you feel more ready to move?", selection: $viewModel.readinessImproved)

                Picker("Would you repeat this flow?", selection: $viewModel.repeatIntent) {
                    Text("Yes").tag(RepeatIntent.yes)
                    Text("Maybe").tag(RepeatIntent.maybe)
                    Text("No").tag(RepeatIntent.no)
                }
                .pickerStyle(.segmented)

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

            Picker(title, selection: selection) {
                Text("Yes").tag(TriStateChoice.yes)
                Text("Maybe").tag(TriStateChoice.maybe)
                Text("No").tag(TriStateChoice.no)
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview {
    PostSessionView(user: .preview, assessment: .preview, service: MockSupabaseService.shared) {}
        .padding()
}
