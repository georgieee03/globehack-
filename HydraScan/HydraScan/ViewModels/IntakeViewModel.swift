import Combine
import Foundation

enum IntakeStep: Int, CaseIterable, Identifiable {
    case bodyMap
    case signals
    case goal
    case activity

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .bodyMap: return "Body Map"
        case .signals: return "Recovery Signals"
        case .goal: return "Goal"
        case .activity: return "Activity Context"
        }
    }
}

@MainActor
final class IntakeViewModel: ObservableObject {
    @Published var currentStep: IntakeStep = .bodyMap
    @Published var selectedRegions: Set<BodyRegion> = []
    @Published var recoverySignals: [BodyRegion: RecoverySignal] = [:]
    @Published var recoveryGoal: RecoveryGoal?
    @Published var activityContext = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    let user: HydraUser

    private let service: SupabaseServiceProtocol
    private(set) var clientProfile: ClientProfile = .empty

    init(user: HydraUser, service: SupabaseServiceProtocol) {
        self.user = user
        self.service = service
    }

    var progressTitle: String {
        "\(currentStep.rawValue + 1) of \(IntakeStep.allCases.count)"
    }

    var orderedSelectedRegions: [BodyRegion] {
        selectedRegions.sorted { $0.displayLabel < $1.displayLabel }
    }

    var canContinue: Bool {
        switch currentStep {
        case .bodyMap:
            return !selectedRegions.isEmpty
        case .signals:
            return orderedSelectedRegions.allSatisfy { recoverySignals[$0] != nil }
        case .goal:
            return recoveryGoal != nil
        case .activity:
            return !activityContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func load() async {
        do {
            let profile = try await service.ensureClientProfile(for: user)
            clientProfile = profile
            selectedRegions = Set(profile.primaryRegions)
            recoveryGoal = profile.goals.first
            activityContext = sanitizedActivityContext(profile.activityContext) ?? ""
            recoverySignals = Dictionary(
                uniqueKeysWithValues: profile.recoverySignals.map { ($0.region, $0) }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggle(region: BodyRegion) {
        if selectedRegions.contains(region) {
            selectedRegions.remove(region)
            recoverySignals.removeValue(forKey: region)
        } else {
            selectedRegions.insert(region)
            recoverySignals[region] = RecoverySignal(
                region: region,
                type: .stiffness,
                severity: 5,
                trigger: ActivityTrigger.general.rawValue,
                notes: nil
            )
        }
    }

    func signal(for region: BodyRegion) -> RecoverySignal {
        recoverySignals[region] ?? RecoverySignal(
            region: region,
            type: .stiffness,
            severity: 5,
            trigger: ActivityTrigger.general.rawValue,
            notes: nil
        )
    }

    func updateSignal(_ signal: RecoverySignal) {
        recoverySignals[signal.region] = signal
    }

    func goBack() {
        guard let previous = IntakeStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    func advance() {
        guard let next = IntakeStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func completeIntake() async -> ClientProfile? {
        guard let recoveryGoal else { return nil }

        isSaving = true
        errorMessage = nil

        let updatedProfile = ClientProfile(
            id: clientProfile.id == ClientProfile.empty.id ? UUID() : clientProfile.id,
            userID: user.id,
            clinicID: user.clinicID,
            primaryRegions: orderedSelectedRegions,
            recoverySignalsByRegion: Dictionary(
                uniqueKeysWithValues: orderedSelectedRegions.compactMap { region in
                    recoverySignals[region].map { (region.rawValue, $0.value) }
                }
            ),
            goals: [recoveryGoal],
            activityContext: activityContext.trimmingCharacters(in: .whitespacesAndNewlines),
            sensitivities: clientProfile.sensitivities,
            notes: clientProfile.notes,
            wearableHRV: clientProfile.wearableHRV,
            wearableStrain: clientProfile.wearableStrain,
            wearableSleepScore: clientProfile.wearableSleepScore,
            wearableLastSync: clientProfile.wearableLastSync,
            createdAt: clientProfile.createdAt == ClientProfile.empty.createdAt ? Date() : clientProfile.createdAt,
            updatedAt: Date()
        )

        do {
            clientProfile = try await service.updateClientProfile(updatedProfile)
            isSaving = false
            return clientProfile
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }

    private func sanitizedActivityContext(_ rawValue: String?) -> String? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        let lowered = trimmed.lowercased()
        if lowered.contains("simulator verification") || lowered.contains("seeded client profile") {
            return nil
        }

        return trimmed
    }
}
