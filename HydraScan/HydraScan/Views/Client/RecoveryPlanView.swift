import Combine
import SafariServices
import SwiftUI

@MainActor
final class RecoveryPlanViewModel: ObservableObject {
    @Published var activePlan: RecoveryPlan?
    @Published var history: [RecoveryPlanHistoryEntry] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    let user: HydraUser

    private let service: SupabaseServiceProtocol
    private let seededPlan: RecoveryPlan?

    init(user: HydraUser, service: SupabaseServiceProtocol, seededPlan: RecoveryPlan? = nil) {
        self.user = user
        self.service = service
        self.seededPlan = seededPlan
        self.activePlan = seededPlan
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let fetchedPlan = service.fetchActiveRecoveryPlan(clientID: user.id)
            async let fetchedHistory = service.fetchRecoveryPlanHistory(clientID: user.id)
            let plan = try await fetchedPlan
            let history = try await fetchedHistory
            activePlan = plan ?? seededPlan
            self.history = history
        } catch {
            if activePlan == nil {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func refreshPlan(force: Bool) async {
        isRefreshing = true
        errorMessage = nil
        infoMessage = nil

        do {
            let result = try await service.refreshRecoveryPlanIfNeeded(
                clientID: user.id,
                assessmentID: nil,
                forceRefresh: force
            )
            activePlan = result.plan
            history = try await service.fetchRecoveryPlanHistory(clientID: user.id)
            infoMessage = result.reason.displayLabel
        } catch {
            errorMessage = error.localizedDescription
        }

        isRefreshing = false
    }

    func log(
        itemID: UUID,
        status: CompletionStatus,
        toleranceRating: Int?,
        difficultyRating: Int?,
        symptomResponse: SymptomResponse?,
        notes: String?
    ) async {
        errorMessage = nil
        infoMessage = nil

        do {
            let updatedPlan = try await service.logRecoveryPlanCompletion(
                clientID: user.id,
                planItemID: itemID,
                status: status,
                toleranceRating: toleranceRating,
                difficultyRating: difficultyRating,
                symptomResponse: symptomResponse,
                notes: notes
            )
            activePlan = updatedPlan
            history = try await service.fetchRecoveryPlanHistory(clientID: user.id)
            infoMessage = "\(status.displayLabel) saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RecoveryPlanView: View {
    @StateObject private var viewModel: RecoveryPlanViewModel

    init(user: HydraUser, service: SupabaseServiceProtocol, initialPlan: RecoveryPlan? = nil) {
        _viewModel = StateObject(wrappedValue: RecoveryPlanViewModel(user: user, service: service, seededPlan: initialPlan))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HydraPageHeader(
                    eyebrow: "Recovery Plan",
                    title: "Your guided movement plan.",
                    subtitle: "HydraScan turns your recovery signals, goals, and recent assessment findings into a curated set of safe instructional exercises."
                )

                if let infoMessage = viewModel.infoMessage {
                    HydraStatusBanner(
                        message: infoMessage,
                        tone: .success,
                        icon: "checkmark.circle.fill"
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    HydraStatusBanner(
                        message: errorMessage,
                        tone: .error,
                        icon: "exclamationmark.triangle.fill"
                    )
                }

                if viewModel.isLoading, viewModel.activePlan == nil {
                    HydraBrandStage(
                        eyebrow: "Recovery Plan",
                        title: "Preparing your current plan.",
                        subtitle: "We’re matching your latest recovery signals to the reviewed HydraScan exercise library.",
                        showsProgress: true
                    )
                } else if let plan = viewModel.activePlan {
                    planHeader(plan)
                    safetyGuidanceCard(plan: plan)
                    progressCard(plan: plan)
                    planItemsSection(title: "Required Items", items: plan.requiredItems)

                    if !plan.optionalSupportItems.isEmpty {
                        planItemsSection(title: "Optional Support", items: plan.optionalSupportItems)
                    }

                    recentHistoryCard(plan: plan)

                    if !viewModel.history.isEmpty {
                        planHistoryCard
                    }
                } else {
                    HydraCard(role: .ivory) {
                        HydraEmptyState(
                            title: "No recovery plan is active yet.",
                            message: "Complete an intake or reassessment capture to generate a curated movement plan from the approved HydraScan exercise catalog.",
                            icon: "play.rectangle",
                            eyebrow: "Recovery Plan",
                            role: .ivory
                        )
                    }
                }

                Button(viewModel.isRefreshing ? "Refreshing Plan…" : "Refresh Plan") {
                    Task {
                        await viewModel.refreshPlan(force: true)
                    }
                }
                .buttonStyle(HydraButtonStyle(kind: .primary))
                .disabled(viewModel.isRefreshing)
            }
            .padding(HydraTheme.Spacing.page)
        }
        .toolbar(.hidden, for: .navigationBar)
        .hydraShell()
        .task {
            await viewModel.load()
        }
    }

    private func planHeader(_ plan: RecoveryPlan) -> some View {
        HydraCard(role: .ivory) {
            Text("Plan Summary")
                .font(HydraTypography.section(28))
                .foregroundStyle(HydraTheme.Colors.ink)

            Text(plan.summary)
                .font(HydraTypography.body(16))
                .foregroundStyle(HydraTheme.Colors.inkSecondary)

            HydraMetricRow(
                label: "Status",
                value: plan.status.displayLabel,
                accent: HydraTheme.Colors.ink,
                labelWidth: 100
            )

            HydraMetricRow(
                label: "Generated From",
                value: plan.refreshReason.displayLabel,
                accent: HydraTheme.Colors.ink,
                labelWidth: 100
            )

            HydraMetricRow(
                label: "Regions",
                value: plan.primaryRegions.isEmpty
                    ? "General movement support"
                    : plan.primaryRegions.map(\.displayLabel).joined(separator: ", "),
                accent: HydraTheme.Colors.ink,
                labelWidth: 100
            )

            if let activityContext = plan.activityContext?.nilIfBlank {
                HydraMetricRow(
                    label: "Context",
                    value: activityContext,
                    accent: HydraTheme.Colors.ink,
                    labelWidth: 100
                )
            }
        }
    }

    private func safetyGuidanceCard(plan: RecoveryPlan) -> some View {
        HydraCard(role: .panel) {
            Text("Safety Guidance")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            if plan.isPausedForSafety {
                HydraStatusBanner(
                    message: plan.safetyPauseReason ?? "This plan is paused for safety. Contact your clinic before continuing.",
                    tone: .warning,
                    icon: "exclamationmark.triangle.fill"
                )
            }

            Text("Stop and contact your clinic if an exercise causes sharp pain, dizziness, numbness, weakness, swelling, recent-trauma symptoms, or anything that feels unsafe.")
                .font(HydraTypography.body(15))
                .foregroundStyle(HydraTheme.Colors.secondaryText)
        }
    }

    private func progressCard(plan: RecoveryPlan) -> some View {
        HydraCard(role: .panel) {
            Text("This Week")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            HydraMetricRow(label: "Completed", value: "\(plan.progress.completedThisWeek)")
            HydraMetricRow(label: "Assigned", value: "\(plan.progress.assignedThisWeek)")
            HydraMetricRow(label: "Completion Rate", value: plan.progress.completionPercentLabel)

            if let nextItem = plan.nextSuggestedItem {
                HydraMetricRow(label: "Next Item", value: nextItem.video.title)
            }
        }
    }

    private func planItemsSection(title: String, items: [RecoveryPlanItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(HydraTypography.section(28))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            ForEach(items) { item in
                NavigationLink {
                    RecoveryPlanItemDetailView(
                        item: item,
                        latestStatus: viewModel.activePlan?.latestStatus(for: item),
                        onLog: { status, tolerance, difficulty, response, notes in
                            Task {
                                await viewModel.log(
                                    itemID: item.id,
                                    status: status,
                                    toleranceRating: tolerance,
                                    difficultyRating: difficulty,
                                    symptomResponse: response,
                                    notes: notes
                                )
                            }
                        }
                    )
                } label: {
                    HydraCard(role: .panel) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.video.title)
                                        .font(HydraTypography.section(24))
                                        .foregroundStyle(HydraTheme.Colors.primaryText)

                                    Text(item.rationale)
                                        .font(HydraTypography.body(15))
                                        .foregroundStyle(HydraTheme.Colors.secondaryText)
                                }

                                Spacer()

                                HydraBrandEmblem(size: 30)
                            }

                            FlowLayout(spacing: 8, lineSpacing: 8) {
                                planChip(item.region.displayLabel)
                                planChip(item.symptom.displayLabel)
                                planChip(item.cadence.displayLabel)
                                planChip(item.itemRole.displayLabel)
                            }

                            if let latestStatus = viewModel.activePlan?.latestStatus(for: item) {
                                HydraMetricRow(label: "Latest Log", value: latestStatus.displayLabel)
                            } else {
                                HydraMetricRow(label: "Latest Log", value: "No activity logged yet")
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func recentHistoryCard(plan: RecoveryPlan) -> some View {
        HydraCard(role: .panel) {
            Text("Recent Completion Activity")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            if plan.sortedRecentLogs.isEmpty {
                Text("Your completion history will appear here once you start logging activity on each exercise item.")
                    .font(HydraTypography.body(15))
                    .foregroundStyle(HydraTheme.Colors.secondaryText)
            } else {
                ForEach(plan.sortedRecentLogs.prefix(5)) { log in
                    HydraMetricRow(
                        label: log.status.displayLabel,
                        value: log.primaryTimestamp.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
        }
    }

    private var planHistoryCard: some View {
        HydraCard(role: .panel) {
            Text("Plan History")
                .font(HydraTypography.section(26))
                .foregroundStyle(HydraTheme.Colors.primaryText)

            ForEach(viewModel.history.prefix(5)) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HydraMetricRow(
                        label: entry.refreshReason.displayLabel,
                        value: "\(Int((entry.completionRate * 100).rounded()))%"
                    )

                    Text(entry.summary)
                        .font(HydraTypography.body(14))
                        .foregroundStyle(HydraTheme.Colors.secondaryText)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func planChip(_ title: String) -> some View {
        Text(title)
            .font(HydraTypography.capsule())
            .foregroundStyle(HydraTheme.Colors.goldSoft)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(HydraTheme.Colors.surfaceRaised)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(HydraTheme.Colors.stroke, lineWidth: 1)
                    )
            )
    }
}

private struct RecoveryPlanItemDetailView: View {
    let item: RecoveryPlanItem
    let latestStatus: CompletionStatus?
    let onLog: (CompletionStatus, Int?, Int?, SymptomResponse?, String?) -> Void

    @Environment(\.openURL) private var openURL
    @State private var showsBrowser = false
    @State private var toleranceRating = 3
    @State private var difficultyRating = 3
    @State private var symptomResponse: SymptomResponse = .same
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HydraPageHeader(
                    eyebrow: item.itemRole.displayLabel,
                    title: item.video.title,
                    subtitle: "Use the linked instructional exercise, then log how the movement felt so HydraScan can keep your plan history accurate."
                )

                HydraCard(role: .ivory) {
                    Text("Instructional Video")
                        .font(HydraTypography.section(28))
                        .foregroundStyle(HydraTheme.Colors.ink)

                    HydraMetricRow(
                        label: "Creator",
                        value: "\(item.video.creatorName) • \(item.video.creatorCredentials)",
                        accent: HydraTheme.Colors.ink,
                        labelWidth: 90
                    )
                    HydraMetricRow(
                        label: "Host",
                        value: item.video.hostLabel,
                        accent: HydraTheme.Colors.ink,
                        labelWidth: 90
                    )
                    HydraMetricRow(
                        label: "Review",
                        value: item.video.humanReviewStatus == .approved ? "Human-reviewed" : item.video.humanReviewStatus.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                        accent: HydraTheme.Colors.ink,
                        labelWidth: 90
                    )
                    HydraMetricRow(
                        label: "Tier",
                        value: sourceQualityLabel(item.video.sourceQualityTier),
                        accent: HydraTheme.Colors.ink,
                        labelWidth: 90
                    )

                    Button("Open Instructional Video") {
                        openVideo()
                    }
                    .buttonStyle(HydraButtonStyle(kind: .primary))
                }

                HydraCard(role: .panel) {
                    Text("Plan Context")
                        .font(HydraTypography.section(26))
                        .foregroundStyle(HydraTheme.Colors.primaryText)

                    HydraMetricRow(label: "Region", value: item.region.displayLabel)
                    HydraMetricRow(label: "Symptom", value: item.symptom.displayLabel)
                    HydraMetricRow(label: "Cadence", value: item.cadence.displayLabel)
                    HydraMetricRow(label: "Weekly Target", value: "\(item.weeklyTargetCount)x")

                    if let latestStatus {
                        HydraMetricRow(label: "Latest Log", value: latestStatus.displayLabel)
                    }

                    Text(item.rationale)
                        .font(HydraTypography.body(15))
                        .foregroundStyle(HydraTheme.Colors.secondaryText)

                    if let displayNotes = item.displayNotes?.nilIfBlank {
                        Text(displayNotes)
                            .font(HydraTypography.body(14))
                            .foregroundStyle(HydraTheme.Colors.secondaryText)
                    }
                }

                HydraCard(role: .panel) {
                    Text("Hydrawav Pairing")
                        .font(HydraTypography.section(26))
                        .foregroundStyle(HydraTheme.Colors.primaryText)

                    HydraMetricRow(label: "Sun Pad", value: item.hydrawavPairing.sunPad.replacingOccurrences(of: "_", with: " ").capitalized)
                    HydraMetricRow(label: "Moon Pad", value: item.hydrawavPairing.moonPad.replacingOccurrences(of: "_", with: " ").capitalized)
                    HydraMetricRow(label: "Intensity", value: item.hydrawavPairing.intensityLabel)
                    HydraMetricRow(label: "Duration", value: item.hydrawavPairing.durationLabel)

                    if let practitionerNote = item.hydrawavPairing.practitionerNote?.nilIfBlank {
                        Text(practitionerNote)
                            .font(HydraTypography.body(14))
                            .foregroundStyle(HydraTheme.Colors.secondaryText)
                    }
                }

                HydraCard(role: .panel) {
                    Text("Safety")
                        .font(HydraTypography.section(26))
                        .foregroundStyle(HydraTheme.Colors.primaryText)

                    Text("Stop and contact your clinic if this causes sharp pain, dizziness, numbness, weakness, swelling, recent-trauma symptoms, or anything that feels unsafe.")
                        .font(HydraTypography.body(15))
                        .foregroundStyle(HydraTheme.Colors.secondaryText)
                }

                HydraCard(role: .panel) {
                    Text("Completion Log")
                        .font(HydraTypography.section(26))
                        .foregroundStyle(HydraTheme.Colors.primaryText)

                    Stepper("Tolerance: \(toleranceRating)/5", value: $toleranceRating, in: 1...5)
                    Stepper("Difficulty: \(difficultyRating)/5", value: $difficultyRating, in: 1...5)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Symptom Response")
                            .font(HydraTypography.ui(15, weight: .semibold))
                            .foregroundStyle(HydraTheme.Colors.primaryText)

                        FlowLayout(spacing: 10, lineSpacing: 10) {
                            ForEach(SymptomResponse.allCases) { response in
                                Button(response.displayLabel) {
                                    symptomResponse = response
                                }
                                .buttonStyle(HydraChipStyle(selected: symptomResponse == response, emphasized: true))
                            }
                        }
                    }

                    HydraInputShell {
                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .font(HydraTypography.body(16))
                            .foregroundStyle(HydraTheme.Colors.primaryText)
                            .background(Color.clear)
                    }

                    VStack(spacing: 10) {
                        Button("Mark Started") {
                            onLog(.started, nil, nil, nil, notes)
                        }
                        .buttonStyle(HydraButtonStyle(kind: .secondary))

                        Button("Mark Completed") {
                            onLog(.completed, toleranceRating, difficultyRating, symptomResponse, notes)
                        }
                        .buttonStyle(HydraButtonStyle(kind: .primary))

                        Button("Skip for Now") {
                            onLog(.skipped, nil, nil, nil, notes)
                        }
                        .buttonStyle(HydraButtonStyle(kind: .secondary))

                        Button("Stop and Flag Safety Concern") {
                            onLog(.stopped, toleranceRating, difficultyRating, symptomResponse, notes)
                        }
                        .buttonStyle(HydraButtonStyle(kind: .secondary))
                    }
                }
            }
            .padding(HydraTheme.Spacing.page)
        }
        .toolbar(.hidden, for: .navigationBar)
        .hydraShell()
        .sheet(isPresented: $showsBrowser) {
            SafariView(url: item.video.canonicalURL)
                .ignoresSafeArea()
        }
    }

    private func openVideo() {
        switch item.video.playbackMode {
        case .externalBrowser:
            openURL(item.video.canonicalURL)
        case .inAppBrowser, .embeddedWeb:
            showsBrowser = true
        }
    }

    private func sourceQualityLabel(_ tier: SourceQualityTier) -> String {
        switch tier {
        case .academicMedical:
            return "Academic / Medical"
        case .ptReviewedPlatform:
            return "PT-Reviewed Platform"
        case .licensedPtCreator:
            return "Licensed PT Creator"
        case .fitnessEducator:
            return "Fitness Educator"
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(HydraTheme.Colors.goldSoft)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        RecoveryPlanView(user: .preview, service: MockSupabaseService.shared)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
