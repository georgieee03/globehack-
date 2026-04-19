import SwiftUI

struct ResultsSummaryView: View {
    let assessment: Assessment
    let persistenceState: AssessmentPersistenceState?
    let onContinue: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Recovery Summary")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("These movement insights combine your intake signals, guided capture, and prior context into a simple session snapshot.")
                        .foregroundStyle(.secondary)
                }

                if let persistenceState {
                    statusBanner(for: persistenceState)
                }

                metricCard(
                    title: "Range of Motion",
                    values: assessment.romValues.mapValues { String(format: "%.0f°", $0) }
                )

                metricCard(
                    title: "Asymmetry",
                    values: assessment.asymmetryScores.mapValues { String(format: "%.1f%%", $0) }
                )

                metricCard(
                    title: "Movement Quality",
                    values: assessment.movementQualityScores.mapValues { String(format: "%.0f%%", $0 * 100) }
                )

                if let recoveryMap = assessment.recoveryMap {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recovery Map")
                            .font(.headline)

                        ForEach(recoveryMap.highlightedRegions) { region in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(region.region.displayLabel)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(region.signalType.displayLabel) • Severity \(region.severity)/10")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let hint = region.compensationHint {
                                    Text(hint)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                    }
                }

                HStack {
                    Button("Start Over") {
                        onStartOver()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Share Feedback") {
                        onContinue()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func metricCard(title: String, values: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(values.keys.sorted(), id: \.self) { key in
                HStack {
                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(values[key] ?? "")
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func statusBanner(for persistenceState: AssessmentPersistenceState) -> some View {
        Label(persistenceState.message, systemImage: persistenceState.iconName)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(persistenceState.tintColor.opacity(0.12))
            )
    }
}

private extension AssessmentPersistenceState {
    var iconName: String {
        switch self {
        case .uploaded:
            return "checkmark.circle.fill"
        case .cachedOffline:
            return "icloud.slash.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .uploaded:
            return .teal
        case .cachedOffline:
            return .orange
        }
    }
}

#Preview {
    ResultsSummaryView(assessment: Assessment.preview, persistenceState: .uploaded("Assessment saved to your recovery timeline."), onContinue: {}, onStartOver: {})
        .padding()
}
