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
            guard let latest = latestAssessment.romValues[key], let first = firstAssessment.romValues[key] else {
                return nil
            }
            return (key, first, latest)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Before & After")
                .font(.headline)

            if !hasComparisonData {
                Text("Complete at least two assessments to unlock your comparison view.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(comparisons, id: \.0) { item in
                    HStack {
                        Text(item.0.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(item.1))° → \(Int(item.2))°")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(item.2 >= item.1 ? .green : .orange)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    BeforeAfterView(firstAssessment: Assessment.preview, latestAssessment: Assessment.preview)
        .padding()
}
