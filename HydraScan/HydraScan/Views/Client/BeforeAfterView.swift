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

        let firstMetrics = combinedMetrics(for: firstAssessment)
        let latestMetrics = combinedMetrics(for: latestAssessment)

        return latestMetrics.keys.sorted().compactMap { key in
            guard
                let latest = latestMetrics[key],
                let first = firstMetrics[key]
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
                    HydraEmptyState(
                        title: "Comparison unlocks after another scan.",
                        message: "Complete at least two assessments to compare how your range of motion is changing over time.",
                        icon: "timeline.selection",
                        eyebrow: "Not enough history",
                        centered: false,
                        role: .ivory
                    )
                } else {
                    ForEach(comparisons, id: \.0) { item in
                        HydraMetricRow(
                            label: ScanMetricCatalog.label(for: item.0),
                            value: "\(formattedValue(for: item.0, value: item.1)) \u{2192} \(formattedValue(for: item.0, value: item.2))",
                            accent: item.2 >= item.1 ? HydraTheme.Colors.success : HydraTheme.Colors.warning
                        )
                    }
                }
            }
        }
    }

    private func combinedMetrics(for assessment: Assessment) -> [String: Double] {
        var metrics = assessment.romValues

        if let quickPoseData = assessment.quickPoseData {
            for stepResult in quickPoseData.stepResults {
                metrics.merge(stepResult.derivedMetrics) { _, new in new }
            }
        }

        return metrics
    }

    private func formattedValue(for key: String, value: Double) -> String {
        if key.contains("score") {
            let normalized = value > 1 ? value : value * 100
            return String(format: "%.0f%%", normalized)
        }

        if key.contains("offset") || key.contains("tracking") || key.contains("wobble") || key.contains("sway") {
            return String(format: "%.1f", value)
        }

        return String(format: "%.0f°", value)
    }
}

#Preview {
    ZStack {
        HydraShellBackground()
        BeforeAfterView(firstAssessment: Assessment.preview, latestAssessment: Assessment.preview)
            .padding()
    }
}
