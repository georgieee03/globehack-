import SwiftUI

struct ResultsSummaryView: View {
    let user: HydraUser
    let service: SupabaseServiceProtocol
    let assessment: Assessment
    let persistenceState: AssessmentPersistenceState?
    let onContinue: () -> Void
    let onStartOver: () -> Void

    @State private var activePlan: RecoveryPlan?
    @State private var isLoadingPlan = false

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

                summaryOverviewCard

                if isLoadingPlan && activePlan == nil {
                    HydraCard(role: .ivory) {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(HydraTheme.Colors.gold)
                            Text("Preparing your linked recovery plan…")
                                .font(HydraTypography.body(15, weight: .medium))
                                .foregroundStyle(HydraTheme.Colors.inkSecondary)
                        }
                    }
                } else if let activePlan {
                    NavigationLink {
                        RecoveryPlanView(user: user, service: service, initialPlan: activePlan)
                    } label: {
                        HydraCard(role: .ivory) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Recovery Plan Ready")
                                    .font(HydraTypography.section(28))
                                    .foregroundStyle(HydraTheme.Colors.ink)

                                Text("Your latest scan now has a linked instructional plan with curated exercise videos, Hydrawav pairing, and completion logging.")
                                    .font(HydraTypography.body(15))
                                    .foregroundStyle(HydraTheme.Colors.inkSecondary)

                                HydraMetricRow(
                                    label: "Plan Status",
                                    value: activePlan.status.displayLabel,
                                    accent: HydraTheme.Colors.ink,
                                    labelWidth: 100
                                )

                                HydraMetricRow(
                                    label: "Next Item",
                                    value: activePlan.nextSuggestedItem?.video.title ?? "Review your plan",
                                    accent: HydraTheme.Colors.ink,
                                    labelWidth: 100
                                )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                metricCard(
                    title: "Range of Motion",
                    values: assessment.romValues.mapValues { String(format: "%.0f°", $0) },
                    category: .rom
                )

                metricCard(
                    title: "Asymmetry",
                    values: assessment.asymmetryScores.mapValues { String(format: "%.1f%%", $0) },
                    category: .asymmetry
                )

                metricCard(
                    title: "Movement Quality",
                    values: assessment.movementQualityScores.mapValues { String(format: "%.0f%%", $0 * 100) },
                    category: .movementQuality
                )

                if let quickPoseData = assessment.quickPoseData {
                    quickPoseSummaryCard(quickPoseData: quickPoseData)
                    onboardingStepSections(quickPoseData: quickPoseData)
                }

                if let recoveryMap = assessment.recoveryMap {
                    HydraCard(role: .ivory) {
                        Text("Recovery Map")
                            .font(HydraTypography.section(28))
                            .foregroundStyle(HydraTheme.Colors.ink)

                        ForEach(Array(recoveryMap.highlightedRegions.enumerated()), id: \.offset) { _, region in
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
                                    .fill(HydraTheme.Colors.ivory.opacity(0.82))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(HydraTheme.Colors.ivoryBorder.opacity(0.6), lineWidth: 1)
                                    )
                            )
                        }
                    }
                } else {
                    HydraCard(role: .ivory) {
                        HydraEmptyState(
                            title: "Recovery map insights will appear here.",
                            message: "When this scan includes enough regional signal context, HydraScan will surface highlighted body regions and compensation notes in this section.",
                            icon: "map",
                            eyebrow: "Recovery Map",
                            role: .ivory
                        )
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
        .task(id: assessment.id) {
            await loadRecoveryPlan()
        }
    }

    private func loadRecoveryPlan() async {
        isLoadingPlan = true
        defer { isLoadingPlan = false }

        do {
            activePlan = try await service.fetchActiveRecoveryPlan(clientID: user.id)
        } catch {
            activePlan = nil
        }
    }

    private func metricCard(title: String, values: [String: String], category: ScanMetricCatalog.MetricCategory) -> some View {
        HydraCard(role: .panel) {
            Text(title)
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            if values.isEmpty {
                let emptyState = aggregateEmptyState(for: title)
                HydraEmptyState(
                    title: emptyState.title,
                    message: emptyState.message,
                    icon: "chart.line.uptrend.xyaxis",
                    eyebrow: emptyState.eyebrow,
                    role: .panel
                )
            } else {
                ForEach(values.keys.sorted(), id: \.self) { key in
                    HydraMetricRow(
                        label: ScanMetricCatalog.label(for: key, category: category),
                        value: values[key] ?? ""
                    )
                }
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

    private var summaryOverviewCard: some View {
        HydraCard(role: .ivory) {
            Text("Session Overview")
                .font(HydraTypography.section(28))
                .foregroundStyle(HydraTheme.Colors.ink)

            HydraMetricRow(
                label: "Focus Regions",
                value: assessment.bodyZones.isEmpty ? "Not specified" : assessment.bodyZones.map(\.displayLabel).joined(separator: ", "),
                accent: HydraTheme.Colors.ink,
                labelWidth: 110
            )

            HydraMetricRow(
                label: "Recovery Goal",
                value: assessment.recoveryGoal?.displayLabel ?? "General assessment",
                accent: HydraTheme.Colors.ink,
                labelWidth: 110
            )

            HydraMetricRow(
                label: "Assessment Type",
                value: assessment.assessmentType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                accent: HydraTheme.Colors.ink,
                labelWidth: 110
            )
        }
    }

    private func quickPoseSummaryCard(quickPoseData: QuickPoseResult) -> some View {
        let landmarkFrameCount = quickPoseData.stepResults.reduce(0) { partialResult, stepResult in
            partialResult + stepResult.landmarks.count
        }

        return HydraCard {
            Text("Scan Details")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            HydraMetricRow(label: "Capture Schema", value: "v\(quickPoseData.schemaVersion)")
            HydraMetricRow(label: "Guided Steps", value: "\(quickPoseData.stepResults.count)")
            HydraMetricRow(
                label: "Landmark Frames",
                value: landmarkFrameCount > 0 ? "\(landmarkFrameCount)" : "Summary only"
            )

            if quickPoseData.repSummaries.isEmpty {
                HydraEmptyState(
                    title: "No repeated movement cycles were detected.",
                    message: "This capture still saved landmark data, range of motion, and movement quality, but it didn’t identify a repeat-based exercise pattern.",
                    icon: "figure.walk.motion",
                    eyebrow: "Scan Details",
                    role: .panel
                )
            } else {
                ForEach(Array(quickPoseData.repSummaries.enumerated()), id: \.offset) { _, summary in
                    HydraMetricRow(
                        label: ScanMetricCatalog.label(for: summary.movement),
                        value: "\(summary.count) rep\(summary.count == 1 ? "" : "s")"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func onboardingStepSections(quickPoseData: QuickPoseResult) -> some View {
        ForEach(Array(quickPoseData.stepResults.enumerated()), id: \.offset) { _, stepResult in
            HydraCard(role: .panel) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(ScanMetricCatalog.title(for: stepResult.step))
                        .font(HydraTypography.section(26))
                        .foregroundStyle(HydraTheme.Colors.primaryText)

                    HydraMetricRow(
                        label: "Confidence",
                        value: "\(Int((stepResult.confidence * 100).rounded()))%"
                    )

                    if stepResult.completenessStatus == .partial {
                        HydraStatusBanner(
                            message: partialStepMessage(for: stepResult),
                            tone: .warning,
                            icon: "exclamationmark.triangle.fill"
                        )
                    }

                    if stepResult.completenessStatus == .insufficientSignal {
                        HydraEmptyState(
                            title: "This step did not return enough signal for a detailed breakdown.",
                            message: "HydraScan still saved the scan, but this pose needs a clearer tracking pass before the detailed metrics can be interpreted confidently.",
                            icon: "figure.stand",
                            eyebrow: ScanMetricCatalog.title(for: stepResult.step),
                            role: .panel
                        )
                    } else {
                        ForEach(Array(stepMetricRows(for: stepResult).enumerated()), id: \.offset) { _, row in
                            HydraMetricRow(label: row.label, value: row.value)
                        }
                    }
                }
            }
        }
    }

    private func stepMetricRows(for stepResult: QuickPoseStepResult) -> [(label: String, value: String)] {
        var rows: [(String, String)] = []

        for key in stepResult.derivedMetrics.keys.sorted() {
            guard let value = stepResult.derivedMetrics[key] else { continue }
            rows.append((ScanMetricCatalog.label(for: key, category: .derived), formattedValue(for: key, value: value)))
        }

        for key in stepResult.romValues.keys.sorted() {
            guard let value = stepResult.romValues[key] else { continue }
            rows.append((ScanMetricCatalog.label(for: key, category: .rom), formattedValue(for: key, value: value)))
        }

        for key in stepResult.asymmetryScores.keys.sorted() {
            guard let value = stepResult.asymmetryScores[key] else { continue }
            rows.append((ScanMetricCatalog.label(for: key, category: .asymmetry), formattedValue(for: key, value: value)))
        }

        return rows
    }

    private func formattedValue(for key: String, value: Double) -> String {
        if key.contains("score") || key.contains("quality") {
            let normalized = value > 1 ? value : value * 100
            return String(format: "%.0f%%", normalized)
        }

        if key.contains("asymmetry") || key.contains("offset") || key.contains("tracking") || key.contains("wobble") || key.contains("sway") {
            return String(format: "%.1f", value)
        }

        return String(format: "%.0f°", value)
    }

    private func aggregateEmptyState(for title: String) -> (eyebrow: String, title: String, message: String) {
        let stepResults = assessment.quickPoseData?.stepResults ?? []

        if stepResults.isEmpty {
            return (
                title.uppercased(),
                "\(title) could not be computed from this scan.",
                "This assessment finished without a usable step-level payload for \(title.lowercased()), so HydraScan could not synthesize the summary metrics."
            )
        }

        let hasUsableStepData = stepResults.contains { $0.completenessStatus != .insufficientSignal }
        if hasUsableStepData {
            return (
                title.uppercased(),
                "\(title) is still missing from the synthesized summary.",
                "The pose-by-pose scan returned usable data below, but HydraScan did not produce a complete aggregate \(title.lowercased()) summary for this assessment."
            )
        }

        return (
            title.uppercased(),
            "\(title) was not measurable with enough confidence in this run.",
            "Every onboarding step completed, but the scan did not return enough reliable signal to synthesize \(title.lowercased()) into the top-level summary."
        )
    }

    private func partialStepMessage(for stepResult: QuickPoseStepResult) -> String {
        let sourceLabel: String = {
            switch stepResult.computationSource {
            case .featureSeries:
                return "feature tracking"
            case .landmarkFallback:
                return "landmark tracking"
            case .mixed:
                return "mixed feature + landmark tracking"
            }
        }()

        if stepResult.missingMetricKeys.isEmpty {
            return "This step was estimated using \(sourceLabel), and HydraScan marked it as partial because some values were confidence-limited."
        }

        let missingPreview = stepResult.missingMetricKeys
            .prefix(3)
            .map { ScanMetricCatalog.label(for: $0) }
            .joined(separator: ", ")

        return "This step was estimated using \(sourceLabel). Some outputs were unavailable: \(missingPreview)."
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
    ResultsSummaryView(
        user: .preview,
        service: MockSupabaseService.shared,
        assessment: Assessment.preview,
        persistenceState: .uploaded("Assessment saved to your recovery timeline."),
        onContinue: {},
        onStartOver: {}
    )
        .padding()
}
