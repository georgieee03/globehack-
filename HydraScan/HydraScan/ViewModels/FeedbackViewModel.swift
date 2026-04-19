import Combine
import Foundation

@MainActor
final class FeedbackViewModel: ObservableObject {
    @Published var stiffnessAfter = 3.0
    @Published var sorenessAfter = 3.0
    @Published var mobilityImproved: TriStateChoice = .yes
    @Published var sessionEffective: TriStateChoice = .yes
    @Published var readinessImproved: TriStateChoice = .maybe
    @Published var repeatIntent: RepeatIntent = .yes
    @Published var clientNotes = ""
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSubmit = false

    let user: HydraUser
    let assessment: Assessment

    private let service: SupabaseServiceProtocol

    init(user: HydraUser, assessment: Assessment, service: SupabaseServiceProtocol) {
        self.user = user
        self.assessment = assessment
        self.service = service
    }

    func submit() async -> Outcome? {
        isSaving = true
        errorMessage = nil

        let outcome = Outcome(
            id: UUID(),
            sessionID: assessment.id,
            clientID: user.id,
            clinicID: user.clinicID,
            recordedBy: .client,
            recordedByUserID: user.id,
            stiffnessBefore: assessment.subjectiveBaseline?.stiffness,
            stiffnessAfter: Int(stiffnessAfter.rounded()),
            sorenessBefore: assessment.subjectiveBaseline?.soreness,
            sorenessAfter: Int(sorenessAfter.rounded()),
            mobilityImproved: mobilityImproved,
            sessionEffective: sessionEffective,
            readinessImproved: readinessImproved,
            repeatIntent: repeatIntent,
            romAfter: assessment.romValues,
            romDelta: assessment.recoveryGraphDelta,
            clientNotes: clientNotes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            practitionerNotes: nil,
            createdAt: Date()
        )

        do {
            let saved = try await service.createOutcome(outcome)
            didSubmit = true
            isSaving = false
            return saved
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }
}
