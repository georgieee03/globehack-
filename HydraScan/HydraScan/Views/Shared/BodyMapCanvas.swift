import SwiftUI

struct BodyMapCanvas: View {
    let selectedRegions: Set<BodyRegion>
    let onToggle: (BodyRegion) -> Void

    private struct RegionLayout {
        let frame: CGRect
        let minimumSize: CGSize
        let cornerRadius: CGFloat
    }

    private static let regionLayouts: [BodyRegion: RegionLayout] = [
        .neck: RegionLayout(
            frame: CGRect(x: 0.41, y: 0.05, width: 0.18, height: 0.07),
            minimumSize: CGSize(width: 60, height: 44),
            cornerRadius: 20
        ),
        .leftShoulder: RegionLayout(
            frame: CGRect(x: 0.11, y: 0.13, width: 0.20, height: 0.08),
            minimumSize: CGSize(width: 78, height: 48),
            cornerRadius: 20
        ),
        .rightShoulder: RegionLayout(
            frame: CGRect(x: 0.69, y: 0.13, width: 0.20, height: 0.08),
            minimumSize: CGSize(width: 78, height: 48),
            cornerRadius: 20
        ),
        .leftArm: RegionLayout(
            frame: CGRect(x: 0.09, y: 0.22, width: 0.15, height: 0.21),
            minimumSize: CGSize(width: 58, height: 108),
            cornerRadius: 24
        ),
        .rightArm: RegionLayout(
            frame: CGRect(x: 0.76, y: 0.22, width: 0.15, height: 0.21),
            minimumSize: CGSize(width: 58, height: 108),
            cornerRadius: 24
        ),
        .upperBack: RegionLayout(
            frame: CGRect(x: 0.31, y: 0.18, width: 0.38, height: 0.12),
            minimumSize: CGSize(width: 118, height: 64),
            cornerRadius: 22
        ),
        .lowerBack: RegionLayout(
            frame: CGRect(x: 0.31, y: 0.31, width: 0.38, height: 0.12),
            minimumSize: CGSize(width: 118, height: 60),
            cornerRadius: 22
        ),
        .leftHip: RegionLayout(
            frame: CGRect(x: 0.27, y: 0.47, width: 0.17, height: 0.08),
            minimumSize: CGSize(width: 64, height: 44),
            cornerRadius: 20
        ),
        .rightHip: RegionLayout(
            frame: CGRect(x: 0.56, y: 0.47, width: 0.17, height: 0.08),
            minimumSize: CGSize(width: 64, height: 44),
            cornerRadius: 20
        ),
        .leftKnee: RegionLayout(
            frame: CGRect(x: 0.27, y: 0.68, width: 0.17, height: 0.08),
            minimumSize: CGSize(width: 64, height: 46),
            cornerRadius: 20
        ),
        .rightKnee: RegionLayout(
            frame: CGRect(x: 0.56, y: 0.68, width: 0.17, height: 0.08),
            minimumSize: CGSize(width: 64, height: 46),
            cornerRadius: 20
        ),
        .leftCalf: RegionLayout(
            frame: CGRect(x: 0.27, y: 0.78, width: 0.16, height: 0.12),
            minimumSize: CGSize(width: 62, height: 68),
            cornerRadius: 22
        ),
        .rightCalf: RegionLayout(
            frame: CGRect(x: 0.57, y: 0.78, width: 0.16, height: 0.12),
            minimumSize: CGSize(width: 62, height: 68),
            cornerRadius: 22
        ),
        .leftFoot: RegionLayout(
            frame: CGRect(x: 0.18, y: 0.91, width: 0.22, height: 0.06),
            minimumSize: CGSize(width: 76, height: 44),
            cornerRadius: 20
        ),
        .rightFoot: RegionLayout(
            frame: CGRect(x: 0.60, y: 0.91, width: 0.22, height: 0.06),
            minimumSize: CGSize(width: 76, height: 44),
            cornerRadius: 20
        ),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                silhouette
                    .frame(width: geometry.size.width, height: geometry.size.height)

                ForEach(BodyRegion.allCases) { region in
                    if let layout = Self.regionLayouts[region] {
                        let isSelected = selectedRegions.contains(region)
                        let width = max(geometry.size.width * layout.frame.width, layout.minimumSize.width)
                        let height = max(geometry.size.height * layout.frame.height, layout.minimumSize.height)
                        let fontSize = width < 72 ? 10.0 : 11.0

                        Button {
                            onToggle(region)
                        } label: {
                            RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                                .fill(
                                    isSelected
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
                                    RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                                        .stroke(
                                            isSelected
                                                ? HydraTheme.Colors.goldOutline.opacity(0.65)
                                                : HydraTheme.Colors.stroke,
                                            lineWidth: isSelected ? 1.8 : 1
                                        )
                                )
                                .overlay(alignment: .center) {
                                    Text(region.bodyCanvasLabel)
                                        .font(HydraTypography.ui(fontSize, weight: .semibold))
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.72)
                                        .allowsTightening(true)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(isSelected ? HydraTheme.Colors.ink : HydraTheme.Colors.secondaryText)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(region.displayLabel)
                        .accessibilityValue(isSelected ? "Selected" : "Not selected")
                        .accessibilityHint(isSelected ? "Double tap to remove this area from today’s scan." : "Double tap to add this area to today’s scan.")
                        .frame(width: width, height: height)
                        .position(
                            x: geometry.size.width * (layout.frame.minX + layout.frame.width / 2),
                            y: geometry.size.height * (layout.frame.minY + layout.frame.height / 2)
                        )
                        .zIndex(isSelected ? 1 : 0)
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

private extension BodyRegion {
    var bodyCanvasLabel: String {
        switch self {
        case .leftShoulder:
            return "Left\nShoulder"
        case .rightShoulder:
            return "Right\nShoulder"
        case .leftHip:
            return "Left\nHip"
        case .rightHip:
            return "Right\nHip"
        case .leftKnee:
            return "Left\nKnee"
        case .rightKnee:
            return "Right\nKnee"
        default:
            return displayLabel
        }
    }
}

#Preview {
    BodyMapCanvas(selectedRegions: [.lowerBack, .rightShoulder]) { _ in }
        .padding()
}
