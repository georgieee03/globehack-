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
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedValue == option.value ? Color.teal.opacity(0.16) : Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selectedValue == option.value ? Color.teal : Color.clear, lineWidth: 1.5)
                    )
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
