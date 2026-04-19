import Combine
import Foundation

enum CaptureFlowState: Equatable {
    case idle
    case capturing
    case results
}

enum AssessmentPersistenceState: Equatable {
    case uploaded(String)
    case cachedOffline(String)

    var message: String {
        switch self {
        case let .uploaded(message), let .cachedOffline(message):
            return message
        }
    }
}

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var flowState: CaptureFlowState = .idle
    @Published var currentStepIndex = 0
    @Published var remainingSeconds = 0
    @Published var repCount = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var latestAssessment: Assessment?
    @Published var persistenceState: AssessmentPersistenceState?

    let user: HydraUser
    let profile: ClientProfile

    private let service: InsforgeServiceProtocol
    private let offlineCacheService: OfflineCacheServiceProtocol
    private var captureTask: Task<Void, Never>?

    init(
        user: HydraUser,
        profile: ClientProfile,
        service: InsforgeServiceProtocol,
        offlineCacheService: OfflineCacheServiceProtocol = OfflineCacheService.shared
    ) {
        self.user = user
        self.profile = profile
        self.service = service
        self.offlineCacheService = offlineCacheService
        remainingSeconds = HydraScanConstants.captureSteps.first?.durationSeconds ?? 0
    }

    var currentStep: CaptureStepDefinition {
        HydraScanConstants.captureSteps[min(currentStepIndex, HydraScanConstants.captureSteps.count - 1)]
    }

    var progressValue: Double {
        guard !HydraScanConstants.captureSteps.isEmpty else { return 0 }
        return Double(currentStepIndex + (flowState == .results ? 1 : 0)) / Double(HydraScanConstants.captureSteps.count)
    }

    func startCapture() {
        guard flowState != .capturing else { return }
        flowState = .capturing
        errorMessage = nil
        currentStepIndex = 0
        repCount = 0
        remainingSeconds = currentStep.durationSeconds

        captureTask?.cancel()
        captureTask = Task {
            for (index, step) in HydraScanConstants.captureSteps.enumerated() {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    currentStepIndex = index
                    remainingSeconds = step.durationSeconds
                    repCount = 0
                }

                for second in stride(from: step.durationSeconds, through: 1, by: -1) {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        remainingSeconds = second
                        repCount = step.step == .squat || step.step == .hipHinge ? max(1, step.durationSeconds - second + 1) : 0
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }

            await finalizeCapture()
        }
    }

    func skipToResults() {
        captureTask?.cancel()
        Task {
            await finalizeCapture()
        }
    }

    func reset() {
        captureTask?.cancel()
        flowState = .idle
        currentStepIndex = 0
        remainingSeconds = HydraScanConstants.captureSteps.first?.durationSeconds ?? 0
        repCount = 0
        latestAssessment = nil
        errorMessage = nil
        persistenceState = nil
    }

    private func finalizeCapture() async {
        isLoading = true
        errorMessage = nil
        persistenceState = nil

        let assessment = Assessment(
            id: UUID(),
            clientID: user.id,
            clinicID: user.clinicID,
            practitionerID: nil,
            assessmentType: .preSession,
            quickPoseData: QuickPoseResult.empty,
            romValues: mockROMValues,
            asymmetryScores: mockAsymmetryScores,
            movementQualityScores: mockMovementQualityScores,
            gaitMetrics: [
                "cadence": 102,
                "stride_balance": 0.94,
            ],
            heartRate: nil,
            breathRate: nil,
            hrvRMSSD: profile.wearableHRV,
            bodyZones: profile.primaryRegions,
            recoveryGoal: profile.goals.first,
            subjectiveBaseline: SubjectiveBaseline(
                stiffness: profile.recoverySignals.first?.severity,
                soreness: profile.recoverySignals.dropFirst().first?.severity,
                notes: profile.activityContext
            ),
            recoveryMap: buildRecoveryMap(),
            recoveryGraphDelta: [
                "mobility_gain": 7,
                "symmetry_shift": 4,
            ],
            createdAt: Date()
        )

        do {
            let uploadedAssessment = try await service.createAssessment(assessment)
            persistenceState = .uploaded("Assessment saved to your recovery timeline.")
            latestAssessment = uploadedAssessment
            flowState = .results
        } catch {
            do {
                try await offlineCacheService.cacheAssessment(assessment)
                persistenceState = .cachedOffline("No connection? This assessment is saved on this device and can sync automatically later.")
                latestAssessment = assessment
                flowState = .results
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func buildRecoveryMap() -> RecoveryMap {
        let regions = profile.recoverySignals.map { signal in
            HighlightedRegion(
                region: signal.region,
                severity: max(1, min(10, signal.severity - 1)),
                signalType: signal.type,
                romDelta: Double(Int.random(in: 3...11)),
                trend: nil,
                asymmetryFlag: signal.severity >= 6,
                compensationHint: signal.severity >= 6 ? "Move a little slower through this region and focus on smoother range." : nil
            )
        }

        let priorSessionSummary = PriorSessionSummary(
            date: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            configSummary: "Mobility reset and supported shoulder flow",
            outcomeRating: 78
        )

        return RecoveryMap(
            clientID: profile.id,
            highlightedRegions: regions.sorted { $0.region.displayLabel < $1.region.displayLabel },
            wearableContext: WearableContext(
                hrv: profile.wearableHRV,
                strain: profile.wearableStrain,
                sleepScore: profile.wearableSleepScore,
                lastSync: profile.wearableLastSync
            ),
            priorSessions: [priorSessionSummary],
            suggestedGoal: profile.goals.first,
            generatedAt: Date()
        )
    }

    private var mockROMValues: [String: Double] {
        [
            "right_shoulder_flexion": 151,
            "left_shoulder_flexion": 146,
            "right_hip_flexion": 121,
            "left_hip_flexion": 117,
            "right_knee_flexion": 131,
            "left_knee_flexion": 125,
        ]
    }

    private var mockAsymmetryScores: [String: Double] {
        [
            "shoulder_flexion": 3.4,
            "hip_flexion": 4.1,
            "knee_flexion": 4.7,
        ]
    }

    private var mockMovementQualityScores: [String: Double] {
        [
            "squat": 0.84,
            "hip_hinge": 0.79,
            "balance": 0.88,
        ]
    }
}
