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
        VStack(alignment: .leading, spacing: 14) {
            Text(region.displayLabel)
                .font(HydraTypography.section(24))
                .foregroundStyle(HydraTheme.Colors.primaryText)

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
                    Text("\(workingSignal.severity)/10")
                        .font(HydraTypography.ui(14, weight: .semibold))
                        .foregroundStyle(HydraTheme.Colors.secondaryText)
                }

                Slider(
                    value: Binding(
                        get: { Double(workingSignal.severity) },
                        set: { workingSignal.severity = Int($0.rounded()) }
                    ),
                    in: 1...10,
                    step: 1
                )
                .tint(HydraTheme.Colors.gold)
            }

            Picker("When do you notice it most?", selection: $workingSignal.trigger) {
                ForEach(ActivityTrigger.allCases) { trigger in
                    Text(trigger.displayLabel).tag(trigger.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(HydraTheme.fill(for: .panel))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(HydraTheme.Colors.stroke, lineWidth: 1)
                )
        )
        .onChange(of: workingSignal) { _, newValue in
            onUpdate(newValue)
        }
    }
}

#Preview {
    SignalEntryView(viewModel: IntakeViewModel(user: .preview, service: MockSupabaseService.shared))
        .padding()
}
