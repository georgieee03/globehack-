import SwiftUI

struct SignalEntryView: View {
    @ObservedObject var viewModel: IntakeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Capture how each area is feeling so the guided session can meet you where you are.")
                    .font(HydraTypography.body(16))
                    .foregroundStyle(HydraTheme.Colors.secondaryText)

                ForEach(viewModel.orderedSelectedRegions) { region in
                    SignalCard(
                        region: region,
                        signal: viewModel.signal(for: region)
                    ) { updated in
                        viewModel.updateSignal(updated)
                    }
                }
            }
        }
    }
}

private struct SignalCard: View {
    let region: BodyRegion
    let signal: RecoverySignal
    let onUpdate: (RecoverySignal) -> Void

    @State private var workingSignal: RecoverySignal

    init(region: BodyRegion, signal: RecoverySignal, onUpdate: @escaping (RecoverySignal) -> Void) {
        self.region = region
        self.signal = signal
        self.onUpdate = onUpdate
        _workingSignal = State(initialValue: signal)
    }

    var body: some View {
        HydraCard(role: .panel) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(region.displayLabel)
                        .font(HydraTypography.section(24))
                        .foregroundStyle(HydraTheme.Colors.primaryText)

                    Text("Describe the dominant signal and when it tends to show up.")
                        .font(HydraTypography.body(14))
                        .foregroundStyle(HydraTheme.Colors.secondaryText)
                }

                Spacer()

                Text("\(workingSignal.severity)/10")
                    .font(HydraTypography.numeric(18))
                    .foregroundStyle(HydraTheme.Colors.goldSoft)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(HydraTheme.Colors.overlay)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(HydraTheme.Colors.gold.opacity(0.24), lineWidth: 1)
                            )
                    )
            }

            Picker("Signal Type", selection: $workingSignal.type) {
                ForEach(RecoverySignalType.allCases) { type in
                    Text(type.displayLabel).tag(type)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Severity")
                        .font(HydraTypography.ui(14, weight: .semibold))
                        .foregroundStyle(HydraTheme.Colors.primaryText)
                    Spacer()
                    Text(severityDescriptor)
                        .font(HydraTypography.ui(14, weight: .medium))
                        .foregroundStyle(HydraTheme.Colors.secondaryText)
                }

                Slider(
                    value: Binding(
                        get: { Double(workingSignal.severity) },
                        set: { workingSignal.severity = Int($0.rounded()) }
                    ),
                    in: 1 ... 10,
                    step: 1
                )
                .tint(HydraTheme.Colors.gold)
            }

            HydraInputShell {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trigger")
                            .font(HydraTypography.ui(13, weight: .semibold))
                            .foregroundStyle(HydraTheme.Colors.secondaryText)
                        Text(ActivityTrigger(rawValue: workingSignal.trigger)?.displayLabel ?? "Select")
                            .font(HydraTypography.ui(15, weight: .semibold))
                            .foregroundStyle(HydraTheme.Colors.primaryText)
                    }

                    Spacer()

                    Picker("When do you notice it most?", selection: $workingSignal.trigger) {
                        ForEach(ActivityTrigger.allCases) { trigger in
                            Text(trigger.displayLabel).tag(trigger.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .onChange(of: workingSignal) { _, newValue in
            onUpdate(newValue)
        }
    }

    private var severityDescriptor: String {
        switch workingSignal.severity {
        case 1 ... 3:
            return "Low"
        case 4 ... 6:
            return "Moderate"
        case 7 ... 8:
            return "Elevated"
        default:
            return "High"
        }
    }
}

#Preview {
    SignalEntryView(viewModel: IntakeViewModel(user: .preview, service: MockSupabaseService.shared))
        .padding()
}
