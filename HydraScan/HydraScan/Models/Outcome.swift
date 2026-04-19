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
}
