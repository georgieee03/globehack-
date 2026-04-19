import SwiftUI

struct ResultsSummaryView: View {
    let assessment: Assessment
    let persistenceState: AssessmentPersistenceState?
    let onContinue: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HydraSectionHeader(
                    eyebrow: "Session Report",
                    title: "Your Recovery Summary",
                    subtitle: "These movement insights combine intake, guided capture, and prior context into one clinical snapshot."
                )

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

                if let quickPoseData = assessment.quickPoseData {
                    quickPoseSummaryCard(quickPoseData: quickPoseData)
                }

                if let recoveryMap = assessment.recoveryMap {
                    HydraCard(role: .ivory) {
                        Text("Recovery Map")
                            .font(HydraTypography.section(28))
                            .foregroundStyle(HydraTheme.Colors.ink)

                        ForEach(recoveryMap.highlightedRegions) { region in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(region.region.displayLabel)
                                    .font(HydraTypography.ui(16, weight: .semibold))
                                    .foregroundStyle(HydraTheme.Colors.ink)
                                Text("\(region.signalType.displayLabel) • Severity \(region.severity)/10")
                                    .font(HydraTypography.body(14, weight: .medium))
                                    .foregroundStyle(HydraTheme.Colors.inkSecondary)

                                if let hint = region.compensationHint {
                                    Text(hint)
                                        .font(HydraTypography.body(13))
                                        .foregroundStyle(HydraTheme.Colors.inkSecondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.68))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(HydraTheme.Colors.ivoryBorder.opacity(0.6), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }

                HStack {
                    Button("Start Over") {
                        onStartOver()
                    }
                    .buttonStyle(HydraButtonStyle(kind: .secondary))

                    Spacer()

                    Button("Share Feedback") {
                        onContinue()
                    }
                    .buttonStyle(HydraButtonStyle(kind: .primary))
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func metricCard(title: String, values: [String: String]) -> some View {
        HydraCard(role: .panel) {
            Text(title)
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            ForEach(values.keys.sorted(), id: \.self) { key in
                HydraMetricRow(
                    label: key.replacingOccurrences(of: "_", with: " ").capitalized,
                    value: values[key] ?? ""
                )
            }
        }
    }

    private func statusBanner(for persistenceState: AssessmentPersistenceState) -> some View {
        HydraStatusBanner(
            message: persistenceState.message,
            tone: {
                switch persistenceState {
                case .uploaded:
                    return .success
                case .cachedOffline:
                    return .warning
                }
            }(),
            icon: persistenceState.iconName
        )
    }

    private func quickPoseSummaryCard(quickPoseData: QuickPoseResult) -> some View {
        HydraCard {
            Text("Scan Details")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            HydraMetricRow(label: "Landmark Frames", value: "\(quickPoseData.landmarks.count)")

            if quickPoseData.repSummaries.isEmpty {
                Text("No repeated movement cycles were detected in this scan.")
                    .font(HydraTypography.body(15))
                    .foregroundStyle(HydraTheme.Colors.secondaryText)
            } else {
                ForEach(quickPoseData.repSummaries) { summary in
                    HydraMetricRow(
                        label: summary.movement.replacingOccurrences(of: "_", with: " ").capitalized,
                        value: "\(summary.count) rep\(summary.count == 1 ? "" : "s")"
                    )
                }
            }
        }
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
}

#Preview {
    ResultsSummaryView(assessment: Assessment.preview, persistenceState: .uploaded("Assessment saved to your recovery timeline."), onContinue: {}, onStartOver: {})
        .padding()
}
