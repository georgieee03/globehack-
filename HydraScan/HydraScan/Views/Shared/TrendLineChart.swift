import SwiftUI

struct TrendLineChart: View {
    let points: [RecoveryScoreTrendPoint]

    var body: some View {
        GeometryReader { geometry in
            let chartHeight = geometry.size.height
            let chartWidth = geometry.size.width
            let values = points.map(\.value)
            let minValue = max(0, (values.min() ?? 0) - 5)
            let maxValue = min(100, (values.max() ?? 100) + 5)

            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .bottomLeading) {
                    Path { path in
                        for step in 0..<4 {
                            let y = chartHeight * CGFloat(step) / 4
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: chartWidth, y: y))
                        }
                    }
                    .stroke(Color.gray.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

                    Path { path in
                        for (index, point) in points.enumerated() {
                            let x = chartWidth * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                            let normalized = CGFloat(point.value - minValue) / CGFloat(max(maxValue - minValue, 1))
                            let y = chartHeight - (normalized * chartHeight)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.teal, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        let x = chartWidth * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                        let normalized = CGFloat(point.value - minValue) / CGFloat(max(maxValue - minValue, 1))
                        let y = chartHeight - (normalized * chartHeight)

                        Circle()
                            .fill(Color.teal)
                            .frame(width: 10, height: 10)
                            .position(x: x, y: y)
                    }
                }
                .frame(height: 150)

                HStack {
                    ForEach(points) { point in
                        Text(point.dayLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 190)
    }
}

#Preview {
    TrendLineChart(points: [
        RecoveryScoreTrendPoint(dayLabel: "Mon", value: 72),
        RecoveryScoreTrendPoint(dayLabel: "Tue", value: 74),
        RecoveryScoreTrendPoint(dayLabel: "Wed", value: 77),
        RecoveryScoreTrendPoint(dayLabel: "Thu", value: 79),
        RecoveryScoreTrendPoint(dayLabel: "Fri", value: 82),
    ])
    .padding()
}
