import Foundation

enum AssessmentType: String, Codable, CaseIterable, Hashable, Identifiable {
    case intake
    case preSession = "pre_session"
    case followUp = "follow_up"
    case reassessment

    var id: String { rawValue }
}

struct SubjectiveBaseline: Codable, Hashable {
    var stiffness: Int?
    var soreness: Int?
    var notes: String?
}

struct Assessment: Identifiable, Codable, Hashable {
    var id: UUID
    var clientID: UUID
    var clinicID: UUID?
    var practitionerID: UUID?
    var assessmentType: AssessmentType
    var quickPoseData: QuickPoseResult?
    var romValues: [String: Double]
    var asymmetryScores: [String: Double]
    var movementQualityScores: [String: Double]
    var gaitMetrics: [String: Double]
    var heartRate: Double?
    var breathRate: Double?
    var hrvRMSSD: Double?
    var bodyZones: [BodyRegion]
    var recoveryGoal: RecoveryGoal?
    var subjectiveBaseline: SubjectiveBaseline?
    var recoveryMap: RecoveryMap?
    var recoveryGraphDelta: [String: Double]
    var createdAt: Date

    static let preview = Assessment(
        id: UUID(),
        clientID: UUID(),
        clinicID: UUID(),
        practitionerID: nil,
        assessmentType: .intake,
        quickPoseData: .empty,
        romValues: [:],
        asymmetryScores: [:],
        movementQualityScores: [:],
        gaitMetrics: [:],
        heartRate: nil,
        breathRate: nil,
        hrvRMSSD: nil,
        bodyZones: [],
        recoveryGoal: .mobility,
        subjectiveBaseline: nil,
        recoveryMap: nil,
        recoveryGraphDelta: [:],
        createdAt: Date()
    )
}
