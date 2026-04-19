import SwiftUI

struct CheckInView: View {
    let user: HydraUser
    let service: SupabaseServiceProtocol
    let onSubmitted: () -> Void

    @State private var overallFeeling = 3
    @State private var selectedRegions: Set<BodyRegion> = []
    @State private var activitySinceLast = ""
    @State private var recommendedRegions: [BodyRegion] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HydraPageHeader(
                        eyebrow: "Daily Check-In",
                        title: "Capture how recovery feels today.",
                        subtitle: "A quick signal check keeps your score, session continuity, and practitioner context up to date."
                    )

                    HydraCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Overall Feeling")
                                .font(HydraTypography.section(26))
                                .foregroundStyle(HydraTheme.Colors.primaryText)
                            EmojiScalePicker(selectedValue: $overallFeeling)
                        }
                    }

                    HydraCard(role: .panel) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Target Regions")
                                .font(HydraTypography.section(26))
                                .foregroundStyle(HydraTheme.Colors.primaryText)
                            Text("Start with the regions from your latest session, then adjust if needed.")
                                .font(HydraTypography.body(15))
                                .foregroundStyle(HydraTheme.Colors.secondaryText)

                            FlowRegionPicker(selectedRegions: $selectedRegions, recommendedRegions: recommendedRegions)
                        }
                    }

                    HydraCard(role: .ivory) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Activity Since Last Session")
                                .font(HydraTypography.section(26))
                                .foregroundStyle(HydraTheme.Colors.ink)
                            HydraInputShell(role: .ivory) {
                                TextEditor(text: $activitySinceLast)
                                    .frame(minHeight: 120)
                                    .scrollContentBackground(.hidden)
                                    .font(HydraTypography.body(16))
                                    .foregroundStyle(HydraTheme.Colors.ink)
                                    .background(Color.clear)
                            }
                        }
                    }

                    if let errorMessage {
                        HydraStatusBanner(message: errorMessage, tone: .error, icon: "exclamationmark.triangle.fill")
                    }

                    Button("Submit Check-In") {
                        Task {
                            await submitCheckIn()
                        }
                    }
                    .buttonStyle(HydraButtonStyle(kind: .primary))
                    .disabled(isSaving)
                }
                .padding(HydraTheme.Spacing.page)
            }
            .toolbar(.hidden, for: .navigationBar)
            .hydraShell()
            .task {
                await loadRecommendedRegions()
            }
        }
    }

    private func loadRecommendedRegions() async {
        do {
            if let assessment = try await service.fetchLatestAssessment(clientID: user.id) {
                recommendedRegions = assessment.bodyZones
                selectedRegions = Set(assessment.bodyZones)
            } else {
                let profile = try await service.fetchClientProfile(userID: user.id)
                recommendedRegions = profile.primaryRegions
                selectedRegions = Set(profile.primaryRegions)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitCheckIn() async {
        isSaving = true
        errorMessage = nil

        let checkIn = DailyCheckin(
            id: UUID(),
            clientID: user.id,
            clinicID: user.clinicID,
            checkinType: .daily,
            overallFeeling: overallFeeling,
            targetRegions: selectedRegions.sorted { $0.displayLabel < $1.displayLabel },
            activitySinceLast: activitySinceLast.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            recoveryScore: Double(overallFeeling * 20),
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            _ = try await service.createCheckin(checkIn)
            isSaving = false
            onSubmitted()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

private struct FlowRegionPicker: View {
    @Binding var selectedRegions: Set<BodyRegion>
    let recommendedRegions: [BodyRegion]

    private var displayedRegions: [BodyRegion] {
        let source = recommendedRegions.isEmpty ? BodyRegion.allCases : recommendedRegions
        return source.sorted { $0.displayLabel < $1.displayLabel }
    }

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(displayedRegions) { region in
                Button(region.displayLabel) {
                    if selectedRegions.contains(region) {
                        selectedRegions.remove(region)
                    } else {
                        selectedRegions.insert(region)
                    }
                }
                .buttonStyle(HydraChipStyle(selected: selectedRegions.contains(region), emphasized: recommendedRegions.contains(region)))
            }
        }
    }
}

#Preview {
    CheckInView(user: .preview, service: MockSupabaseService.shared) {}
}
