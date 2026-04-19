import SwiftUI

struct BodyMapView: View {
    @ObservedObject var viewModel: IntakeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Select the regions that need the most support right now.")
                .font(HydraTypography.body(16))
                .foregroundStyle(HydraTheme.Colors.secondaryText)

            HydraCard(role: .panel, padding: 16) {
                BodyMapCanvas(selectedRegions: viewModel.selectedRegions) { region in
                    viewModel.toggle(region: region)
                }
                .frame(maxWidth: .infinity)
            }

            HydraMetricRow(
                label: "Regions Selected",
                value: "\(viewModel.selectedRegions.count)",
                accent: HydraTheme.Colors.goldSoft
            )
        }
    }
}

#Preview {
    BodyMapView(viewModel: IntakeViewModel(user: .preview, service: MockSupabaseService.shared))
        .padding()
}
