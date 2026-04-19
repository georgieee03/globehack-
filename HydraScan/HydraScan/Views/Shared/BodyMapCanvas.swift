import SwiftUI

struct BodyMapCanvas: View {
    let selectedRegions: Set<BodyRegion>
    let onToggle: (BodyRegion) -> Void

    private static let regionFrames: [BodyRegion: CGRect] = [
        .neck: CGRect(x: 0.43, y: 0.06, width: 0.14, height: 0.06),
        .leftShoulder: CGRect(x: 0.19, y: 0.13, width: 0.17, height: 0.08),
        .rightShoulder: CGRect(x: 0.64, y: 0.13, width: 0.17, height: 0.08),
        .leftArm: CGRect(x: 0.10, y: 0.22, width: 0.14, height: 0.22),
        .rightArm: CGRect(x: 0.76, y: 0.22, width: 0.14, height: 0.22),
        .upperBack: CGRect(x: 0.34, y: 0.18, width: 0.32, height: 0.12),
        .lowerBack: CGRect(x: 0.35, y: 0.31, width: 0.30, height: 0.12),
        .leftHip: CGRect(x: 0.30, y: 0.45, width: 0.14, height: 0.08),
        .rightHip: CGRect(x: 0.56, y: 0.45, width: 0.14, height: 0.08),
        .leftKnee: CGRect(x: 0.31, y: 0.66, width: 0.12, height: 0.08),
        .rightKnee: CGRect(x: 0.57, y: 0.66, width: 0.12, height: 0.08),
        .leftCalf: CGRect(x: 0.30, y: 0.76, width: 0.13, height: 0.12),
        .rightCalf: CGRect(x: 0.57, y: 0.76, width: 0.13, height: 0.12),
        .leftFoot: CGRect(x: 0.25, y: 0.90, width: 0.18, height: 0.06),
        .rightFoot: CGRect(x: 0.57, y: 0.90, width: 0.18, height: 0.06),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                silhouette
                    .frame(width: geometry.size.width, height: geometry.size.height)

                ForEach(BodyRegion.allCases) { region in
                    if let frame = Self.regionFrames[region] {
                        Button {
                            onToggle(region)
                        } label: {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    selectedRegions.contains(region)
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [
                                                    HydraTheme.Colors.goldSoft.opacity(0.92),
                                                    HydraTheme.Colors.gold.opacity(0.92),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        : AnyShapeStyle(HydraTheme.Colors.surface.opacity(0.16))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            selectedRegions.contains(region)
                                                ? HydraTheme.Colors.goldOutline.opacity(0.65)
                                                : HydraTheme.Colors.stroke,
                                            lineWidth: selectedRegions.contains(region) ? 1.8 : 1
                                        )
                                )
                                .overlay(alignment: .center) {
                                    Text(region.displayLabel)
                                        .font(HydraTypography.ui(11, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(selectedRegions.contains(region) ? HydraTheme.Colors.ink : HydraTheme.Colors.secondaryText)
                                        .padding(4)
                                }
                        }
                        .buttonStyle(.plain)
                        .frame(
                            width: geometry.size.width * frame.width,
                            height: geometry.size.height * frame.height
                        )
                        .position(
                            x: geometry.size.width * (frame.minX + frame.width / 2),
                            y: geometry.size.height * (frame.minY + frame.height / 2)
                        )
                    }
                }
            }
        }
        .aspectRatio(0.72, contentMode: .fit)
    }

    private var silhouette: some View {
        ZStack {
            Circle()
                .fill(HydraTheme.Colors.primaryText.opacity(0.08))
                .frame(width: 82, height: 82)
                .offset(y: -188)

            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(HydraTheme.Colors.primaryText.opacity(0.07))
                .frame(width: 140, height: 210)
                .offset(y: -48)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(HydraTheme.Colors.primaryText.opacity(0.05))
                .frame(width: 48, height: 150)
                .offset(x: -108, y: -58)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(HydraTheme.Colors.primaryText.opacity(0.05))
                .frame(width: 48, height: 150)
                .offset(x: 108, y: -58)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(HydraTheme.Colors.primaryText.opacity(0.05))
                .frame(width: 56, height: 220)
                .offset(x: -38, y: 170)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(HydraTheme.Colors.primaryText.opacity(0.05))
                .frame(width: 56, height: 220)
                .offset(x: 38, y: 170)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(HydraTheme.Colors.stroke, lineWidth: 1)
                .padding(10)
        )
    }
}

#Preview {
    BodyMapCanvas(selectedRegions: [.lowerBack, .rightShoulder]) { _ in }
        .padding()
}
