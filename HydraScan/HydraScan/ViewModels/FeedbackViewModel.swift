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

    private let service: InsforgeServiceProtocol

    init(user: HydraUser, assessment: Assessment, service: InsforgeServiceProtocol) {
        self.user = user
        self.assessment = assessment
        self.service = service
    }

    func submit() async -> Outcome? {
        isSaving = true
        errorMessage = nil

        do {
            let sessionID = try await resolveSessionID()
            let outcome = Outcome(
                id: UUID(),
                sessionID: sessionID,
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

    private func resolveSessionID() async throws -> UUID {
        let recentSessions = try await service.fetchSessions(clientID: user.id, limit: 10)

        if let matchingSession = recentSessions.first(where: { $0.assessmentID == assessment.id }) {
            return matchingSession.id
        }

        if let latestSession = recentSessions.first {
            return latestSession.id
        }

        return assessment.id
    }
}
