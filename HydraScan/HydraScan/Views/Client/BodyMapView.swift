import SwiftUI

struct BodyMapView: View {
    @ObservedObject var viewModel: IntakeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Select the regions that need the most support right now.")
                .foregroundStyle(.secondary)

            BodyMapCanvas(selectedRegions: viewModel.selectedRegions) { region in
                viewModel.toggle(region: region)
            }
            .frame(maxWidth: .infinity)

            Text("\(viewModel.selectedRegions.count) regions selected")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    BodyMapView(viewModel: IntakeViewModel(user: .preview, service: MockInsforgeService.shared))
        .padding()
}
