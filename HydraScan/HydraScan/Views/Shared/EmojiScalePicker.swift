import SwiftUI

struct EmojiScalePicker: View {
    @Binding var selectedValue: Int

    private let options: [(value: Int, emoji: String, label: String)] = [
        (1, "😣", "Low"),
        (2, "🙂", "Okay"),
        (3, "😊", "Steady"),
        (4, "😄", "Good"),
        (5, "🌟", "Excellent"),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.value) { option in
                Button {
                    selectedValue = option.value
                } label: {
                    VStack(spacing: 8) {
                        Text(option.emoji)
                            .font(.system(size: 28))
                        Text(option.label)
                            .font(HydraTypography.ui(12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                selectedValue == option.value
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [HydraTheme.Colors.goldSoft, HydraTheme.Colors.gold],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(HydraTheme.fill(for: .panel))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                selectedValue == option.value
                                    ? HydraTheme.Colors.goldOutline.opacity(0.55)
                                    : HydraTheme.Colors.stroke,
                                lineWidth: 1.2
                            )
                    )
                    .foregroundStyle(selectedValue == option.value ? HydraTheme.Colors.ink : HydraTheme.Colors.primaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    EmojiScalePicker(selectedValue: .constant(3))
        .padding()
}
