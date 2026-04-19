import SwiftUI

struct ActivityContextView: View {
    @ObservedObject var viewModel: IntakeViewModel

    private let suggestions = [
        "Desk-heavy day",
        "Lifted this morning",
        "Long run yesterday",
        "Travel stiffness",
        "Recovery between practices",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add a little context about what your body has been doing lately.")
                .foregroundStyle(.secondary)

            TextEditor(text: $viewModel.activityContext)
                .frame(minHeight: 140)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

            Text("Quick ideas")
                .font(.headline)

            FlowLayout(spacing: 10, lineSpacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        if viewModel.activityContext.isEmpty {
                            viewModel.activityContext = suggestion
                        } else {
                            viewModel.activityContext += ", \(suggestion.lowercased())"
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)
                }
            }
        }
    }
}

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ActivityContextView(viewModel: IntakeViewModel(user: .preview, service: MockSupabaseService.shared))
        .padding()
}
