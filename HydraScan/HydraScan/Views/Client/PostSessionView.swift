import SwiftUI

struct PostSessionView: View {
    @StateObject private var viewModel: FeedbackViewModel
    let onSubmitted: () -> Void

    init(user: HydraUser, assessment: Assessment, service: InsforgeServiceProtocol, onSubmitted: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(user: user, assessment: assessment, service: service))
        self.onSubmitted = onSubmitted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Post-Session Feedback")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("A quick reflection helps keep your Recovery Score and practitioner summary up to date.")
                        .foregroundStyle(.secondary)
                }

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
                        .font(.headline)
                    TextEditor(text: $viewModel.clientNotes)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                Button("Submit Feedback") {
                    Task {
                        if await viewModel.submit() != nil {
                            onSubmitted()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSaving)
            }
            .padding(.vertical, 12)
        }
    }

    private func sliderCard(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))/10")
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: 0...10, step: 1)
                .tint(.teal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func triStatePicker(title: String, selection: Binding<TriStateChoice>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

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
    PostSessionView(user: .preview, assessment: .preview, service: MockInsforgeService.shared) {}
        .padding()
}
