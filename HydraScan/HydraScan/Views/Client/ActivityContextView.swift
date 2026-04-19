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
                .font(HydraTypography.body(16))
                .foregroundStyle(HydraTheme.Colors.secondaryText)

            HydraInputShell {
                TextEditor(text: $viewModel.activityContext)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .font(HydraTypography.body(16))
                    .foregroundStyle(HydraTheme.Colors.primaryText)
                    .background(Color.clear)
            }

            Text("Quick ideas")
                .font(HydraTypography.ui(15, weight: .semibold))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            FlowLayout(spacing: 10, lineSpacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        if viewModel.activityContext.isEmpty {
                            viewModel.activityContext = suggestion
                        } else {
                            viewModel.activityContext += ", \(suggestion.lowercased())"
                        }
                    }
                    .buttonStyle(HydraChipStyle(selected: false, emphasized: true))
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
