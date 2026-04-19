import Foundation

#if canImport(Supabase)
import Supabase
#endif

protocol SupabaseServiceProtocol {
    func ensureClientProfile(for user: HydraUser) async throws -> ClientProfile
    func fetchClientProfile(userID: UUID) async throws -> ClientProfile
    func updateClientProfile(_ profile: ClientProfile) async throws -> ClientProfile
    func createAssessment(_ assessment: Assessment) async throws -> Assessment
    func fetchAssessments(clientID: UUID) async throws -> [Assessment]
    func fetchLatestAssessment(clientID: UUID) async throws -> Assessment?
    func createOutcome(_ outcome: Outcome) async throws -> Outcome
    func fetchLatestOutcome(clientID: UUID) async throws -> Outcome?
    func createCheckin(_ checkin: DailyCheckin) async throws -> DailyCheckin
    func fetchRecentCheckins(clientID: UUID, limit: Int) async throws -> [DailyCheckin]
    func fetchRecoveryScore(clientID: UUID) async throws -> RecoveryScore
    func fetchRecoveryTrend(clientID: UUID) async throws -> [RecoveryScoreTrendPoint]
}

enum SupabaseServiceError: LocalizedError {
    case missingUser
    case missingProfile
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingUser:
            return "Sign in to continue."
        case .missingProfile:
            return "No recovery profile was found for this user yet."
        case let .unavailable(message):
            return message
        }
    }
}

actor MockSupabaseService: SupabaseServiceProtocol {
    static let shared = MockSupabaseService()

    private var profilesByUserID: [UUID: ClientProfile] = [:]
    private var assessmentsByClientID: [UUID: [Assessment]] = [:]
    private var outcomesByClientID: [UUID: [Outcome]] = [:]
    private var checkinsByClientID: [UUID: [DailyCheckin]] = [:]

    func ensureClientProfile(for user: HydraUser) async throws -> ClientProfile {
        if let profile = profilesByUserID[user.id] {
            return profile
        }

        let profile = ClientProfile(
            id: UUID(),
            userID: user.id,
            clinicID: user.clinicID,
            primaryRegions: [],
            recoverySignalsByRegion: [:],
            goals: [],
            activityContext: nil,
            sensitivities: [],
            notes: nil,
            wearableHRV: 54,
            wearableStrain: 31,
            wearableSleepScore: 82,
            wearableLastSync: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        profilesByUserID[user.id] = profile
        return profile
    }

    func fetchClientProfile(userID: UUID) async throws -> ClientProfile {
        guard let profile = profilesByUserID[userID] else {
            throw SupabaseServiceError.missingProfile
        }

        return profile
    }

    func updateClientProfile(_ profile: ClientProfile) async throws -> ClientProfile {
        let updatedProfile = ClientProfile(
            id: profile.id,
            userID: profile.userID,
            clinicID: profile.clinicID,
            primaryRegions: profile.primaryRegions,
            recoverySignalsByRegion: profile.recoverySignalsByRegion,
            goals: profile.goals,
            activityContext: profile.activityContext,
            sensitivities: profile.sensitivities,
            notes: profile.notes,
            wearableHRV: profile.wearableHRV,
            wearableStrain: profile.wearableStrain,
            wearableSleepScore: profile.wearableSleepScore,
            wearableLastSync: profile.wearableLastSync,
            createdAt: profile.createdAt,
            updatedAt: Date()
        )
        profilesByUserID[profile.userID] = updatedProfile
        return updatedProfile
    }

    func createAssessment(_ assessment: Assessment) async throws -> Assessment {
        var assessments = assessmentsByClientID[assessment.clientID, default: []]
        assessments.insert(assessment, at: 0)
        assessmentsByClientID[assessment.clientID] = assessments
        return assessment
    }

    func fetchAssessments(clientID: UUID) async throws -> [Assessment] {
        assessmentsByClientID[clientID, default: []]
    }

    func fetchLatestAssessment(clientID: UUID) async throws -> Assessment? {
        assessmentsByClientID[clientID]?.first
    }

    func createOutcome(_ outcome: Outcome) async throws -> Outcome {
        var outcomes = outcomesByClientID[outcome.clientID, default: []]
        outcomes.insert(outcome, at: 0)
        outcomesByClientID[outcome.clientID] = outcomes
        return outcome
    }

    func fetchLatestOutcome(clientID: UUID) async throws -> Outcome? {
        outcomesByClientID[clientID]?.first
    }

    func createCheckin(_ checkin: DailyCheckin) async throws -> DailyCheckin {
        var checkins = checkinsByClientID[checkin.clientID, default: []]
        checkins.insert(checkin, at: 0)
        checkinsByClientID[checkin.clientID] = checkins
        return checkin
    }

    func fetchRecentCheckins(clientID: UUID, limit: Int) async throws -> [DailyCheckin] {
        Array(checkinsByClientID[clientID, default: []].prefix(limit))
    }

    func fetchRecoveryScore(clientID: UUID) async throws -> RecoveryScore {
        let recentCheckins = checkinsByClientID[clientID, default: []]
        let trend = buildTrend(from: recentCheckins)
        let latestValue = trend.last?.value ?? 82
        let previousValue = trend.dropLast().last?.value ?? max(latestValue - 4, 0)

        return RecoveryScore(
            current: latestValue,
            deltaFromLastWeek: latestValue - previousValue,
            updatedAt: Date(),
            trend: trend
        )
    }

    func fetchRecoveryTrend(clientID: UUID) async throws -> [RecoveryScoreTrendPoint] {
        buildTrend(from: checkinsByClientID[clientID, default: []])
    }

    private func buildTrend(from checkins: [DailyCheckin]) -> [RecoveryScoreTrendPoint] {
        if checkins.isEmpty {
            return [
                RecoveryScoreTrendPoint(dayLabel: "Mon", value: 72),
                RecoveryScoreTrendPoint(dayLabel: "Tue", value: 74),
                RecoveryScoreTrendPoint(dayLabel: "Wed", value: 77),
                RecoveryScoreTrendPoint(dayLabel: "Thu", value: 79),
                RecoveryScoreTrendPoint(dayLabel: "Fri", value: 82),
            ]
        }

        let calendar = Calendar.current
        let reversed = Array(checkins.prefix(5).reversed())

        return reversed.enumerated().map { index, checkin in
            let date = calendar.date(byAdding: .day, value: index - reversed.count + 1, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            let feelingScore = max(0, min(100, checkin.overallFeeling * 20))

            return RecoveryScoreTrendPoint(
                dayLabel: formatter.string(from: date),
                value: feelingScore
            )
        }
    }
}

#if canImport(Supabase)
final class LiveSupabaseService: SupabaseServiceProtocol {
    private let client: SupabaseClient

    init() throws {
        guard
            let url = HydraScanConstants.supabaseURL,
            !HydraScanConstants.supabaseAnonKey.isEmpty
        else {
            throw SupabaseServiceError.unavailable("Set SUPABASE_URL and SUPABASE_ANON_KEY before using the live service.")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: HydraScanConstants.supabaseAnonKey
        )
    }

    func ensureClientProfile(for user: HydraUser) async throws -> ClientProfile {
        _ = client
        throw SupabaseServiceError.unavailable("Live Supabase profile sync is not wired yet.")
    }

    func fetchClientProfile(userID: UUID) async throws -> ClientProfile {
        _ = userID
        throw SupabaseServiceError.unavailable("Live Supabase profile fetch is not wired yet.")
    }

    func updateClientProfile(_ profile: ClientProfile) async throws -> ClientProfile {
        _ = profile
        throw SupabaseServiceError.unavailable("Live Supabase profile updates are not wired yet.")
    }

    func createAssessment(_ assessment: Assessment) async throws -> Assessment {
        _ = assessment
        throw SupabaseServiceError.unavailable("Live assessment upload is not wired yet.")
    }

    func fetchAssessments(clientID: UUID) async throws -> [Assessment] {
        _ = clientID
        throw SupabaseServiceError.unavailable("Live assessment queries are not wired yet.")
    }

    func fetchLatestAssessment(clientID: UUID) async throws -> Assessment? {
        _ = clientID
        throw SupabaseServiceError.unavailable("Live assessment queries are not wired yet.")
    }

    func createOutcome(_ outcome: Outcome) async throws -> Outcome {
        _ = outcome
        throw SupabaseServiceError.unavailable("Live outcome submission is not wired yet.")
    }

    func fetchLatestOutcome(clientID: UUID) async throws -> Outcome? {
        _ = clientID
        throw SupabaseServiceError.unavailable("Live outcome queries are not wired yet.")
    }

    func createCheckin(_ checkin: DailyCheckin) async throws -> DailyCheckin {
        _ = checkin
        throw SupabaseServiceError.unavailable("Live check-in submission is not wired yet.")
    }

    func fetchRecentCheckins(clientID: UUID, limit: Int) async throws -> [DailyCheckin] {
        _ = (clientID, limit)
        throw SupabaseServiceError.unavailable("Live check-in queries are not wired yet.")
    }

    func fetchRecoveryScore(clientID: UUID) async throws -> RecoveryScore {
        _ = clientID
        throw SupabaseServiceError.unavailable("Live recovery score queries are not wired yet.")
    }

    func fetchRecoveryTrend(clientID: UUID) async throws -> [RecoveryScoreTrendPoint] {
        _ = clientID
        throw SupabaseServiceError.unavailable("Live recovery trend queries are not wired yet.")
    }
}
#endif
