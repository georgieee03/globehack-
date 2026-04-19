import Foundation

enum OutcomeActor: String, Codable, CaseIterable, Hashable, Identifiable {
    case client
    case practitioner

    var id: String { rawValue }
}

enum TriStateChoice: String, Codable, CaseIterable, Hashable, Identifiable {
    case yes
    case maybe
    case no

    var id: String { rawValue }
}

enum RepeatIntent: String, Codable, CaseIterable, Hashable, Identifiable {
    case yes
    case maybe
    case no
    case noTryDifferent = "no_try_different"

    var id: String { rawValue }
}

struct Outcome: Identifiable, Codable, Hashable {
    var id: UUID
    var sessionID: UUID
    var clientID: UUID
    var clinicID: UUID?
    var recordedBy: OutcomeActor
    var recordedByUserID: UUID?
    var stiffnessBefore: Int?
    var stiffnessAfter: Int?
    var sorenessBefore: Int?
    var sorenessAfter: Int?
    var mobilityImproved: TriStateChoice?
    var sessionEffective: TriStateChoice?
    var readinessImproved: TriStateChoice?
    var repeatIntent: RepeatIntent?
    var romAfter: [String: Double]
    var romDelta: [String: Double]
    var clientNotes: String?
    var practitionerNotes: String?
    var createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case clientID = "client_id"
        case clinicID = "clinic_id"
        case recordedBy = "recorded_by"
        case recordedByUserID = "recorded_by_user_id"
        case stiffnessBefore = "stiffness_before"
        case stiffnessAfter = "stiffness_after"
        case sorenessBefore = "soreness_before"
        case sorenessAfter = "soreness_after"
        case mobilityImproved = "mobility_improved"
        case sessionEffective = "session_effective"
        case readinessImproved = "readiness_improved"
        case repeatIntent = "repeat_intent"
        case romAfter = "rom_after"
        case romDelta = "rom_delta"
        case clientNotes = "client_notes"
        case practitionerNotes = "practitioner_notes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        sessionID: UUID,
        clientID: UUID,
        clinicID: UUID?,
        recordedBy: OutcomeActor,
        recordedByUserID: UUID?,
        stiffnessBefore: Int?,
        stiffnessAfter: Int?,
        sorenessBefore: Int?,
        sorenessAfter: Int?,
        mobilityImproved: TriStateChoice?,
        sessionEffective: TriStateChoice?,
        readinessImproved: TriStateChoice?,
        repeatIntent: RepeatIntent?,
        romAfter: [String: Double],
        romDelta: [String: Double],
        clientNotes: String?,
        practitionerNotes: String?,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.clientID = clientID
        self.clinicID = clinicID
        self.recordedBy = recordedBy
        self.recordedByUserID = recordedByUserID
        self.stiffnessBefore = stiffnessBefore
        self.stiffnessAfter = stiffnessAfter
        self.sorenessBefore = sorenessBefore
        self.sorenessAfter = sorenessAfter
        self.mobilityImproved = mobilityImproved
        self.sessionEffective = sessionEffective
        self.readinessImproved = readinessImproved
        self.repeatIntent = repeatIntent
        self.romAfter = romAfter
        self.romDelta = romDelta
        self.clientNotes = clientNotes
        self.practitionerNotes = practitionerNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
