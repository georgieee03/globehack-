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

            HydraCard(role: .ivory) {
                Text("Quick Ideas")
                    .font(HydraTypography.section(24))
                    .foregroundStyle(HydraTheme.Colors.ink)

                Text("Tap any prompt to seed the note and keep the intake moving.")
                    .font(HydraTypography.body(15))
                    .foregroundStyle(HydraTheme.Colors.inkSecondary)

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
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    init(spacing: CGFloat, lineSpacing: CGFloat) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedWidth = currentRowWidth == 0 ? size.width : currentRowWidth + spacing + size.width

            if proposedWidth > maxWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + lineSpacing
                maxRowWidth = max(maxRowWidth, currentRowWidth)
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth = proposedWidth
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        totalHeight += currentRowHeight
        maxRowWidth = max(maxRowWidth, currentRowWidth)

        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += rowHeight + lineSpacing
                rowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ActivityContextView(viewModel: IntakeViewModel(user: .preview, service: MockSupabaseService.shared))
        .padding()
}
