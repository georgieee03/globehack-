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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Check-In")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Take 30 seconds to mark how recovery feels today.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overall Feeling")
                            .font(.headline)
                        EmojiScalePicker(selectedValue: $overallFeeling)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Target Regions")
                            .font(.headline)
                        Text("Start with the regions from your latest session, then adjust if needed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        FlowRegionPicker(selectedRegions: $selectedRegions, recommendedRegions: recommendedRegions)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Activity Since Last Session")
                            .font(.headline)
                        TextEditor(text: $activitySinceLast)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }

                    Button("Submit Check-In") {
                        Task {
                            await submitCheckIn()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                }
                .padding(24)
            }
            .navigationTitle("Check-In")
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
                recommendedRegions = ClientProfile.preview.primaryRegions
                selectedRegions = Set(ClientProfile.preview.primaryRegions)
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
                .buttonStyle(.bordered)
                .tint(selectedRegions.contains(region) ? .teal : (recommendedRegions.contains(region) ? .orange : .gray))
            }
        }
    }
}

#Preview {
    CheckInView(user: .preview, service: MockSupabaseService.shared) {}
}
