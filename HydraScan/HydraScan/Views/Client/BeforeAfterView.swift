import SwiftUI

struct BeforeAfterView: View {
    let firstAssessment: Assessment?
    let latestAssessment: Assessment?

    private var hasComparisonData: Bool {
        guard let firstAssessment, let latestAssessment else { return false }
        return firstAssessment.id != latestAssessment.id && !comparisons.isEmpty
    }

    private var comparisons: [(String, Double, Double)] {
        guard let firstAssessment, let latestAssessment else { return [] }

        return latestAssessment.romValues.keys.sorted().compactMap { key in
            guard
                let latest = latestAssessment.romValues[key],
                let first = firstAssessment.romValues[key]
            else {
                return nil
            }

            return (key, first, latest)
        }
    }

    var body: some View {
        HydraCard(role: .ivory) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Before & After")
                    .font(HydraTypography.section(28))
                    .foregroundStyle(HydraTheme.Colors.ink)

                if !hasComparisonData {
                    Text("Complete at least two assessments to unlock your comparison view.")
                        .font(HydraTypography.body(15))
                        .foregroundStyle(HydraTheme.Colors.inkSecondary)
                } else {
                    ForEach(comparisons, id: \.0) { item in
                        HydraMetricRow(
                            label: item.0.replacingOccurrences(of: "_", with: " ").capitalized,
                            value: "\(Int(item.1))° \u{2192} \(Int(item.2))°",
                            accent: item.2 >= item.1 ? HydraTheme.Colors.success : HydraTheme.Colors.warning
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        HydraShellBackground()
        BeforeAfterView(firstAssessment: Assessment.preview, latestAssessment: Assessment.preview)
            .padding()
    }
}
