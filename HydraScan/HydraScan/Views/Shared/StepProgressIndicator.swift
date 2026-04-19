import SwiftUI

struct StepProgressIndicator: View {
    let title: String
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(currentStep)/\(totalSteps)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index < currentStep ? Color.teal : Color.teal.opacity(0.16))
                        .frame(height: 8)
                }
            }
        }
    }
}

#Preview {
    StepProgressIndicator(title: "Capture Progress", currentStep: 3, totalSteps: 7)
        .padding()
}
