import SwiftUI

struct BodyMapView: View {
    @ObservedObject var viewModel: IntakeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tap every area that feels stiff, sore, or limited right now. Tap again to remove it.")
                .font(HydraTypography.body(16))
                .foregroundStyle(HydraTheme.Colors.secondaryText)

            HydraCard(role: .panel, padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose your focus areas for today’s scan.")
                        .font(HydraTypography.ui(15, weight: .semibold))
                        .foregroundStyle(HydraTheme.Colors.primaryText)

                    BodyMapCanvas(selectedRegions: viewModel.selectedRegions) { region in
                        viewModel.toggle(region: region)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HydraMetricRow(
                label: "Areas Selected",
                value: "\(viewModel.selectedRegions.count)",
                accent: HydraTheme.Colors.goldSoft
            )

            if viewModel.selectedRegions.isEmpty {
                HydraCard(role: .panel) {
                    HydraEmptyState(
                        title: "Select at least one area to start the guided scan.",
                        message: "Choose every area you want HydraScan to focus on today. You can select more than one.",
                        icon: "figure.stand",
                        eyebrow: "Body Map",
                        role: .panel
                    )
                }
            } else {
                HydraCard(role: .ivory) {
                    Text("Your Focus Areas")
                        .font(HydraTypography.section(24))
                        .foregroundStyle(HydraTheme.Colors.ink)

                    Text("These selections guide the scan sequence and the recovery notes saved after the session.")
                        .font(HydraTypography.body(15))
                        .foregroundStyle(HydraTheme.Colors.inkSecondary)

                    FlowLayout(spacing: 10, lineSpacing: 10) {
                        ForEach(viewModel.orderedSelectedRegions) { region in
                            Text(region.displayLabel)
                                .font(HydraTypography.ui(14, weight: .semibold))
                                .foregroundStyle(HydraTheme.Colors.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(HydraTheme.Colors.ivory.opacity(0.7))
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(HydraTheme.Colors.ivoryBorder.opacity(0.7), lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    BodyMapView(viewModel: IntakeViewModel(user: .preview, service: MockSupabaseService.shared))
        .padding()
}
