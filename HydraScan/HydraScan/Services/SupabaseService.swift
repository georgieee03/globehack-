import Foundation

#if canImport(Supabase)
import Supabase
#endif

@MainActor
protocol SupabaseServiceProtocol {
    func currentSessionContext() async -> HydraSessionContext?
    func ensureClientProfile(for user: HydraUser) async throws -> ClientProfile
    func fetchClientProfile(userID: UUID) async throws -> ClientProfile
    func updateClientProfile(_ profile: ClientProfile) async throws -> ClientProfile
    func createAssessment(_ assessment: Assessment) async throws -> Assessment
    func fetchAssessments(clientID: UUID) async throws -> [Assessment]
    func fetchLatestAssessment(clientID: UUID) async throws -> Assessment?
    func fetchSessions(clientID: UUID, limit: Int) async throws -> [HydraSession]
    func fetchLatestSession(clientID: UUID, statuses: [HydraSessionStatus]?) async throws -> HydraSession?
    func fetchSessionAwareness(clientID: UUID) async throws -> HydraSessionAwareness
    func sessionAwarenessStream(clientID: UUID) -> AsyncThrowingStream<HydraSessionAwareness, Error>
    func createOutcome(_ outcome: Outcome) async throws -> Outcome
    func fetchLatestOutcome(clientID: UUID) async throws -> Outcome?
    func createCheckin(_ checkin: DailyCheckin) async throws -> DailyCheckin
    func fetchRecentCheckins(clientID: UUID, limit: Int) async throws -> [DailyCheckin]
    func fetchRecoveryScore(clientID: UUID) async throws -> RecoveryScore
    func fetchRecoveryTrend(clientID: UUID) async throws -> [RecoveryScoreTrendPoint]
    func claimClinicInvite(inviteCode: String, fullName: String) async throws -> HydraSessionContext
    func resetSessionContext() async
}

enum SupabaseServiceError: LocalizedError {
    case missingUser
    case missingProfile
    case missingSession
    case incompleteOnboarding
    case missingCallbackConfiguration
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingUser:
            return "Sign in to continue."
        case .missingProfile:
            return "No recovery profile was found for this user yet."
        case .missingSession:
            return "No Hydrawav session is available for this outcome yet."
        case .incompleteOnboarding:
            return "Your clinic access is still being provisioned. Please try again in a moment."
        case .missingCallbackConfiguration:
            return "This build is missing an app callback URL for email sign-in."
        case let .unavailable(message):
            return message
        }
    }
}

@MainActor
final class HydraSessionStore {
    static let shared = HydraSessionStore()

    private var context: HydraSessionContext?

    func currentContext() -> HydraSessionContext? {
        context
    }

    func update(_ context: HydraSessionContext?) {
        self.context = context
    }
}

enum HydraRuntime {
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private static func infoString(forKey key: String) -> String? {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.nilIfBlank
    }

    private static func infoBool(forKey key: String) -> Bool {
        let rawValue = infoString(forKey: key)?.lowercased() ?? ""
        return rawValue == "1" || rawValue == "yes" || rawValue == "true"
    }

    static var qaAutologinCredentials: (email: String, password: String)? {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["HYDRASCAN_SIMULATOR_AUTOLOGIN"] == "1" {
            guard
                let email = environment["HYDRASCAN_QA_EMAIL"]?.nilIfBlank,
                let password = environment["HYDRASCAN_QA_PASSWORD"]?.nilIfBlank
            else {
                return nil
            }

            return (email, password)
        }

        guard infoBool(forKey: "HYDRASCAN_DEBUG_AUTOLOGIN") else {
            return nil
        }

        guard
            let email = infoString(forKey: "DEV_QA_EMAIL"),
            let password = infoString(forKey: "DEV_QA_PASSWORD")
        else {
            return nil
        }

        return (email, password)
        #else
        return nil
        #endif
    }

    static var authCallbackURL: URL? {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier, !bundleIdentifier.isEmpty else {
            return nil
        }

        return URL(string: "\(bundleIdentifier)://auth-callback")
    }

    static let shouldUseLiveServices: Bool = {
        #if canImport(Supabase)
        !isPreview && HydraSupabaseCore.shared != nil
        #else
        false
        #endif
    }()
}

@MainActor
final class MockSupabaseService: SupabaseServiceProtocol {
    static let shared = MockSupabaseService()

    private let liveService: LiveSupabaseService?
    private var profilesByUserID: [UUID: ClientProfile] = [:]
    private var assessmentsByClientID: [UUID: [Assessment]] = [:]
    private var outcomesByClientID: [UUID: [Outcome]] = [:]
    private var checkinsByClientID: [UUID: [DailyCheckin]] = [:]
    private var sessionsByClientID: [UUID: [HydraSession]] = [:]

    init(useLiveServices: Bool? = nil) {
        if useLiveServices ?? HydraRuntime.shouldUseLiveServices {
            liveService = try? LiveSupabaseService()
        } else {
            liveService = nil
        }
    }

    func currentSessionContext() async -> HydraSessionContext? {
        if let liveService {
            return await liveService.currentSessionContext()
        }

        return await HydraSessionStore.shared.currentContext()
    }

    func ensureClientProfile(for user: HydraUser) async throws -> ClientProfile {
        if let liveService {
            return try await liveService.ensureClientProfile(for: user)
        }

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
            trendClassification: .insufficientData,
            needsAttention: false,
            nextVisitSignal: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        profilesByUserID[user.id] = profile
        return profile
    }

    func fetchClientProfile(userID: UUID) async throws -> ClientProfile {
        if let liveService {
            return try await liveService.fetchClientProfile(userID: userID)
        }

        guard let profile = profilesByUserID[userID] else {
            throw SupabaseServiceError.missingProfile
        }

        return profile
    }

    func updateClientProfile(_ profile: ClientProfile) async throws -> ClientProfile {
        if let liveService {
            return try await liveService.updateClientProfile(profile)
        }

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
            trendClassification: profile.trendClassification,
            needsAttention: profile.needsAttention,
            nextVisitSignal: profile.nextVisitSignal,
            createdAt: profile.createdAt,
            updatedAt: Date()
        )
        profilesByUserID[profile.userID] = updatedProfile
        return updatedProfile
    }

    func createAssessment(_ assessment: Assessment) async throws -> Assessment {
        if let liveService {
            return try await liveService.createAssessment(assessment)
        }

        var assessments = assessmentsByClientID[assessment.clientID, default: []]
        assessments.insert(assessment, at: 0)
        assessmentsByClientID[assessment.clientID] = assessments
        return assessment
    }

    func fetchAssessments(clientID: UUID) async throws -> [Assessment] {
        if let liveService {
            return try await liveService.fetchAssessments(clientID: clientID)
        }

        return assessmentsByClientID[clientID, default: []]
    }

    func fetchLatestAssessment(clientID: UUID) async throws -> Assessment? {
        if let liveService {
            return try await liveService.fetchLatestAssessment(clientID: clientID)
        }

        return assessmentsByClientID[clientID]?.first
    }

    func fetchSessions(clientID: UUID, limit: Int) async throws -> [HydraSession] {
        if let liveService {
            return try await liveService.fetchSessions(clientID: clientID, limit: limit)
        }

        return Array(sessionsByClientID[clientID, default: []].prefix(limit))
    }

    func fetchLatestSession(clientID: UUID, statuses: [HydraSessionStatus]?) async throws -> HydraSession? {
        if let liveService {
            return try await liveService.fetchLatestSession(clientID: clientID, statuses: statuses)
        }

        let sessions = sessionsByClientID[clientID, default: []]
        guard let statuses, !statuses.isEmpty else {
            return sessions.first
        }

        return sessions.first(where: { statuses.contains($0.status) })
    }

    func fetchSessionAwareness(clientID: UUID) async throws -> HydraSessionAwareness {
        if let liveService {
            return try await liveService.fetchSessionAwareness(clientID: clientID)
        }

        return HydraSessionAwareness(
            activeSession: sessionsByClientID[clientID, default: []].first(where: { $0.status == .active || $0.status == .paused }),
            latestSession: sessionsByClientID[clientID, default: []].first,
            updatedAt: Date()
        )
    }

    func sessionAwarenessStream(clientID: UUID) -> AsyncThrowingStream<HydraSessionAwareness, Error> {
        if let liveService {
            return liveService.sessionAwarenessStream(clientID: clientID)
        }

        return AsyncThrowingStream { continuation in
            Task {
                continuation.yield(
                    HydraSessionAwareness(
                        activeSession: self.sessionsByClientID[clientID, default: []].first(where: { $0.status == .active || $0.status == .paused }),
                        latestSession: self.sessionsByClientID[clientID, default: []].first,
                        updatedAt: Date()
                    )
                )
                continuation.finish()
            }
        }
    }

    func createOutcome(_ outcome: Outcome) async throws -> Outcome {
        if let liveService {
            return try await liveService.createOutcome(outcome)
        }

        var outcomes = outcomesByClientID[outcome.clientID, default: []]
        outcomes.insert(outcome, at: 0)
        outcomesByClientID[outcome.clientID] = outcomes
        return outcome
    }

    func fetchLatestOutcome(clientID: UUID) async throws -> Outcome? {
        if let liveService {
            return try await liveService.fetchLatestOutcome(clientID: clientID)
        }

        return outcomesByClientID[clientID]?.first
    }

    func createCheckin(_ checkin: DailyCheckin) async throws -> DailyCheckin {
        if let liveService {
            return try await liveService.createCheckin(checkin)
        }

        var checkins = checkinsByClientID[checkin.clientID, default: []]
        checkins.insert(checkin, at: 0)
        checkinsByClientID[checkin.clientID] = checkins
        return checkin
    }

    func fetchRecentCheckins(clientID: UUID, limit: Int) async throws -> [DailyCheckin] {
        if let liveService {
            return try await liveService.fetchRecentCheckins(clientID: clientID, limit: limit)
        }

        return Array(checkinsByClientID[clientID, default: []].prefix(limit))
    }

    func fetchRecoveryScore(clientID: UUID) async throws -> RecoveryScore {
        if let liveService {
            return try await liveService.fetchRecoveryScore(clientID: clientID)
        }

        let trend = buildTrend(from: checkinsByClientID[clientID, default: []])
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
        if let liveService {
            return try await liveService.fetchRecoveryTrend(clientID: clientID)
        }

        return buildTrend(from: checkinsByClientID[clientID, default: []])
    }

    func claimClinicInvite(inviteCode: String, fullName: String) async throws -> HydraSessionContext {
        if let liveService {
            return try await liveService.claimClinicInvite(inviteCode: inviteCode, fullName: fullName)
        }

        let appUser = HydraUser(
            id: UUID(),
            clinicID: UUID(),
            role: .client,
            email: nil,
            fullName: fullName,
            phone: nil,
            dateOfBirth: nil,
            authProvider: "demo",
            avatarURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let profile = ClientProfile(
            id: UUID(),
            userID: appUser.id,
            clinicID: appUser.clinicID,
            primaryRegions: [],
            recoverySignalsByRegion: [:],
            goals: [],
            activityContext: nil,
            sensitivities: [],
            notes: "Invite \(inviteCode)",
            wearableHRV: nil,
            wearableStrain: nil,
            wearableSleepScore: nil,
            wearableLastSync: nil,
            trendClassification: .insufficientData,
            needsAttention: false,
            nextVisitSignal: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        profilesByUserID[appUser.id] = profile

        let authUser = HydraAuthUser(
            id: appUser.id,
            email: appUser.email,
            phone: appUser.phone,
            providers: [appUser.authProvider ?? "demo"],
            lastSignInAt: Date(),
            createdAt: appUser.createdAt,
            updatedAt: appUser.updatedAt
        )
        let context = HydraSessionContext(
            authUserID: appUser.id,
            userID: appUser.id,
            clinicID: appUser.clinicID,
            role: .client,
            clientProfileID: profile.id,
            authUser: authUser,
            appUser: appUser,
            clinic: nil
        )
        await HydraSessionStore.shared.update(context)
        return context
    }

    func resetSessionContext() async {
        if let liveService {
            await liveService.resetSessionContext()
            return
        }

        await HydraSessionStore.shared.update(nil)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "E"

        return reversed.enumerated().map { index, checkin in
            let date = calendar.date(byAdding: .day, value: index - reversed.count + 1, to: Date()) ?? Date()
            let feelingScore = max(0, min(100, checkin.overallFeeling * 20))

            return RecoveryScoreTrendPoint(
                dayLabel: formatter.string(from: date),
                value: feelingScore
            )
        }
    }
}

#if canImport(Supabase)
private struct RecoveryGraphScoreRow: Decodable {
    var value: Double
    var recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case value
        case recordedAt = "recorded_at"
    }
}

private struct OutcomeRecorderRequest: Encodable {
    var sessionID: UUID
    var recordedBy: String
    var stiffnessBefore: Int?
    var stiffnessAfter: Int
    var sorenessAfter: Int?
    var mobilityImproved: Bool?
    var sessionEffective: Bool?
    var repeatIntent: String
    var romAfter: [String: Double]?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case recordedBy = "recorded_by"
        case stiffnessBefore = "stiffness_before"
        case stiffnessAfter = "stiffness_after"
        case sorenessAfter = "soreness_after"
        case mobilityImproved = "mobility_improved"
        case sessionEffective = "session_effective"
        case repeatIntent = "repeat_intent"
        case romAfter = "rom_after"
        case notes
    }
}

private struct OutcomeRecorderResponse: Decodable {
    var success: Bool
    var outcomeId: UUID
    var recoveryScore: Double?
    var trend: TrendClassification?
    var nextVisitSignal: NextVisitSignal?
}

private struct ClaimClinicInviteRequest: Encodable {
    var inviteCode: String
    var fullName: String

    enum CodingKeys: String, CodingKey {
        case inviteCode = "invite_code"
        case fullName = "full_name"
    }
}

private struct ClaimClinicInviteResponse: Decodable {
    var success: Bool
    var clinicId: UUID
    var role: UserRole
    var clientProfileId: UUID

    enum CodingKeys: String, CodingKey {
        case success
        case clinicId = "clinicId"
        case role
        case clientProfileId = "clientProfileId"
    }
}

private struct CheckinRecorderRequest: Encodable {
    var checkinType: CheckinType
    var overallFeeling: Int
    var targetRegions: [BodyRegion]
    var activitySinceLast: String?

    enum CodingKeys: String, CodingKey {
        case checkinType = "checkin_type"
        case overallFeeling = "overall_feeling"
        case targetRegions = "target_regions"
        case activitySinceLast = "activity_since_last"
    }
}

private struct CheckinRecorderResponse: Decodable {
    var success: Bool
    var checkinId: UUID
    var recoveryScore: Double?

    enum CodingKeys: String, CodingKey {
        case success
        case checkinId = "checkinId"
        case recoveryScore = "recoveryScore"
    }
}

private struct RecoveryIntelligenceActionRequest: Encodable {
    var action: String
    var clientID: UUID
    var assessmentID: UUID?

    enum CodingKeys: String, CodingKey {
        case action
        case clientID = "client_id"
        case assessmentID = "assessment_id"
    }
}

private struct RecoveryMapFunctionResponse: Decodable {
    struct Payload: Decodable {
        var recoveryMap: RecoveryMap
    }

    var success: Bool
    var action: String
    var data: Payload
}

private struct RecoveryMapPatch: Encodable {
    var recoveryMap: RecoveryMap

    enum CodingKeys: String, CodingKey {
        case recoveryMap = "recovery_map"
    }
}

private struct RecoveryScoreFunctionResponse: Decodable {
    struct Payload: Decodable {
        var score: Double
        var computedAt: String?

        enum CodingKeys: String, CodingKey {
            case score
            case computedAt = "computedAt"
        }
    }

    var success: Bool
    var action: String
    var data: Payload
}

private struct OutcomePatch: Encodable {
    var sorenessBefore: Int?
    var readinessImproved: String?
    var repeatIntent: String?
    var romDelta: [String: Double]?
    var clientNotes: String?
    var practitionerNotes: String?

    enum CodingKeys: String, CodingKey {
        case sorenessBefore = "soreness_before"
        case readinessImproved = "readiness_improved"
        case repeatIntent = "repeat_intent"
        case romDelta = "rom_delta"
        case clientNotes = "client_notes"
        case practitionerNotes = "practitioner_notes"
    }

    var isEmpty: Bool {
        sorenessBefore == nil
            && readinessImproved == nil
            && repeatIntent == nil
            && romDelta == nil
            && clientNotes == nil
            && practitionerNotes == nil
    }
}

private struct CheckinScorePatch: Encodable {
    var recoveryScore: Double

    enum CodingKeys: String, CodingKey {
        case recoveryScore = "recovery_score"
    }
}

@MainActor
final class HydraSupabaseCore {
    static let shared: HydraSupabaseCore? = try? HydraSupabaseCore()

    let client: SupabaseClient

    init() throws {
        guard
            let url = HydraScanConstants.supabaseURL,
            !HydraScanConstants.supabaseAnonKey.isEmpty
        else {
            throw SupabaseServiceError.unavailable("Set SUPABASE_URL and SUPABASE_ANON_KEY before using the live service.")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: HydraScanConstants.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: HydraRuntime.authCallbackURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    func currentSessionContext() async -> HydraSessionContext? {
        if let cached = await HydraSessionStore.shared.currentContext() {
            return cached
        }

        if let currentSession = client.auth.currentSession {
            return try? await loadSessionContext(from: currentSession.user, allowProvisioningRetry: false)
        }

        if let session = try? await client.auth.session {
            return try? await loadSessionContext(from: session.user, allowProvisioningRetry: false)
        }

        return nil
    }

    func requireCurrentSessionContext() async throws -> HydraSessionContext {
        if let context = await currentSessionContext() {
            return context
        }

        throw SupabaseServiceError.missingUser
    }

    func loadSessionContext(from authUser: User, allowProvisioningRetry: Bool) async throws -> HydraSessionContext {
        let maxAttempts = allowProvisioningRetry ? 8 : 1
        var attempt = 0

        while attempt < maxAttempts {
            if let appUser = try await fetchUser(id: authUser.id) {
                let profile = try await fetchClientProfile(userID: appUser.id)
                let clinic = try await fetchClinic(id: appUser.clinicID)
                let context = HydraSessionContext(
                    authUserID: authUser.id,
                    userID: appUser.id,
                    clinicID: appUser.clinicID,
                    role: appUser.role,
                    clientProfileID: profile?.id,
                    authUser: mapAuthUser(authUser, appUser: appUser),
                    appUser: appUser,
                    clinic: clinic
                )
                await HydraSessionStore.shared.update(context)
                return context
            }

            attempt += 1
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        throw SupabaseServiceError.incompleteOnboarding
    }

    func resolveClientProfileID(for identifier: UUID) async throws -> UUID {
        if let context = await HydraSessionStore.shared.currentContext() {
            if identifier == context.clientProfileID || identifier == context.userID || identifier == context.authUserID,
               let clientProfileID = context.clientProfileID {
                return clientProfileID
            }
        }

        if let profile = try await fetchClientProfile(id: identifier) {
            return profile.id
        }

        if let profile = try await fetchClientProfile(userID: identifier) {
            return profile.id
        }

        throw SupabaseServiceError.missingProfile
    }

    func fetchUser(id: UUID) async throws -> HydraUser? {
        let rows: [HydraUser] = try await client
            .from("users")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func fetchClinic(id: UUID?) async throws -> HydraClinic? {
        guard let id else { return nil }

        let rows: [HydraClinic] = try await client
            .from("clinics")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func fetchClientProfile(id: UUID) async throws -> ClientProfile? {
        let rows: [ClientProfile] = try await client
            .from("client_profiles")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func fetchClientProfile(userID: UUID) async throws -> ClientProfile? {
        let rows: [ClientProfile] = try await client
            .from("client_profiles")
            .select()
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    private func mapAuthUser(_ authUser: User, appUser: HydraUser) -> HydraAuthUser {
        var providers = Set(authUser.identities?.map(\.provider) ?? [])
        if let provider = appUser.authProvider {
            providers.insert(provider)
        }

        return HydraAuthUser(
            id: authUser.id,
            email: authUser.email,
            phone: authUser.phone,
            providers: Array(providers).sorted(),
            lastSignInAt: authUser.lastSignInAt,
            createdAt: authUser.createdAt,
            updatedAt: authUser.updatedAt
        )
    }
}

@MainActor
final class LiveSupabaseService: SupabaseServiceProtocol {
    private let core: HydraSupabaseCore

    init() throws {
        guard let core = HydraSupabaseCore.shared else {
            throw SupabaseServiceError.unavailable("Set SUPABASE_URL and SUPABASE_ANON_KEY before using the live service.")
        }

        self.core = core
    }

    func currentSessionContext() async -> HydraSessionContext? {
        await core.currentSessionContext()
    }

    func ensureClientProfile(for user: HydraUser) async throws -> ClientProfile {
        if let profile = try await core.fetchClientProfile(userID: user.id) {
            return profile
        }

        let context = try await core.requireCurrentSessionContext()
        if let profile = try await core.fetchClientProfile(userID: context.userID) {
            return profile
        }

        throw SupabaseServiceError.missingProfile
    }

    func fetchClientProfile(userID: UUID) async throws -> ClientProfile {
        if let profile = try await core.fetchClientProfile(userID: userID) {
            return profile
        }

        let resolvedProfileID = try await core.resolveClientProfileID(for: userID)
        if let profile = try await core.fetchClientProfile(id: resolvedProfileID) {
            return profile
        }

        throw SupabaseServiceError.missingProfile
    }

    func updateClientProfile(_ profile: ClientProfile) async throws -> ClientProfile {
        let resolvedProfileID = try await core.resolveClientProfileID(for: profile.id)
        let preparedProfile = ClientProfile(
            id: resolvedProfileID,
            userID: profile.userID,
            clinicID: profile.clinicID,
            primaryRegions: profile.primaryRegions,
            recoverySignalsByRegion: profile.recoverySignalsByRegion,
            goals: profile.goals,
            activityContext: profile.activityContext?.nilIfBlank,
            sensitivities: profile.sensitivities,
            notes: profile.notes?.nilIfBlank,
            wearableHRV: profile.wearableHRV,
            wearableStrain: profile.wearableStrain,
            wearableSleepScore: profile.wearableSleepScore,
            wearableLastSync: profile.wearableLastSync,
            trendClassification: profile.trendClassification,
            needsAttention: profile.needsAttention,
            nextVisitSignal: profile.nextVisitSignal,
            createdAt: profile.createdAt,
            updatedAt: Date()
        )

        let rows: [ClientProfile] = try await core.client
            .from("client_profiles")
            .update(preparedProfile)
            .eq("id", value: preparedProfile.id.uuidString)
            .select()
            .limit(1)
            .execute()
            .value

        guard let saved = rows.first else {
            throw SupabaseServiceError.missingProfile
        }

        if let context = await HydraSessionStore.shared.currentContext(), context.userID == saved.userID {
            await HydraSessionStore.shared.update(
                HydraSessionContext(
                    authUserID: context.authUserID,
                    userID: context.userID,
                    clinicID: saved.clinicID,
                    role: context.role,
                    clientProfileID: saved.id,
                    authUser: context.authUser,
                    appUser: context.appUser,
                    clinic: context.clinic
                )
            )
        }

        return saved
    }

    func createAssessment(_ assessment: Assessment) async throws -> Assessment {
        let clientProfileID = try await core.resolveClientProfileID(for: assessment.clientID)
        let preparedAssessment = Assessment(
            id: assessment.id,
            clientID: clientProfileID,
            clinicID: assessment.clinicID,
            practitionerID: assessment.practitionerID,
            assessmentType: assessment.assessmentType,
            quickPoseData: assessment.quickPoseData,
            romValues: assessment.romValues,
            asymmetryScores: assessment.asymmetryScores,
            movementQualityScores: assessment.movementQualityScores,
            gaitMetrics: assessment.gaitMetrics,
            heartRate: assessment.heartRate,
            breathRate: assessment.breathRate,
            hrvRMSSD: assessment.hrvRMSSD,
            bodyZones: assessment.bodyZones,
            recoveryGoal: assessment.recoveryGoal,
            subjectiveBaseline: assessment.subjectiveBaseline,
            recoveryMap: assessment.recoveryMap,
            recoveryGraphDelta: assessment.recoveryGraphDelta,
            createdAt: assessment.createdAt
        )

        let rows: [Assessment] = try await core.client
            .from("assessments")
            .insert(preparedAssessment)
            .select()
            .limit(1)
            .execute()
            .value

        guard var saved = rows.first else {
            throw SupabaseServiceError.unavailable("The assessment was submitted but no row was returned.")
        }

        do {
            let recoveryMapResponse: RecoveryMapFunctionResponse = try await core.client.functions.invoke(
                "recovery-intelligence",
                options: FunctionInvokeOptions(
                    body: RecoveryIntelligenceActionRequest(
                        action: "recovery-map",
                        clientID: clientProfileID,
                        assessmentID: saved.id
                    )
                )
            )

            if recoveryMapResponse.success {
                let updatedRows: [Assessment] = try await core.client
                    .from("assessments")
                    .update(RecoveryMapPatch(recoveryMap: recoveryMapResponse.data.recoveryMap))
                    .eq("id", value: saved.id.uuidString)
                    .select()
                    .limit(1)
                    .execute()
                    .value

                if let updated = updatedRows.first {
                    saved = updated
                } else {
                    saved.recoveryMap = recoveryMapResponse.data.recoveryMap
                }
            }
        } catch {
            // Assessment persistence should still succeed even if recovery-map generation fails.
        }

        do {
            let _: RecoveryScoreFunctionResponse = try await core.client.functions.invoke(
                "recovery-intelligence",
                options: FunctionInvokeOptions(
                    body: RecoveryIntelligenceActionRequest(
                        action: "recovery-score",
                        clientID: clientProfileID,
                        assessmentID: saved.id
                    )
                )
            )
        } catch {
            // A saved assessment should not fail just because the score refresh route is unavailable.
        }

        return saved
    }

    func fetchAssessments(clientID: UUID) async throws -> [Assessment] {
        let clientProfileID = try await core.resolveClientProfileID(for: clientID)

        let rows: [Assessment] = try await core.client
            .from("assessments")
            .select()
            .eq("client_id", value: clientProfileID.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows
    }

    func fetchLatestAssessment(clientID: UUID) async throws -> Assessment? {
        try await fetchAssessments(clientID: clientID).first
    }

    func fetchSessions(clientID: UUID, limit: Int) async throws -> [HydraSession] {
        let clientProfileID = try await core.resolveClientProfileID(for: clientID)

        let rows: [HydraSession] = try await core.client
            .from("sessions")
            .select()
            .eq("client_id", value: clientProfileID.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows
    }

    func fetchLatestSession(clientID: UUID, statuses: [HydraSessionStatus]? = nil) async throws -> HydraSession? {
        let clientProfileID = try await core.resolveClientProfileID(for: clientID)
        let rows: [HydraSession] = try await core.client
            .from("sessions")
            .select()
            .eq("client_id", value: clientProfileID.uuidString)
            .order("created_at", ascending: false)
            .limit(10)
            .execute()
            .value

        guard let statuses, !statuses.isEmpty else {
            return rows.first
        }

        return rows.first(where: { statuses.contains($0.status) })
    }

    func fetchSessionAwareness(clientID: UUID) async throws -> HydraSessionAwareness {
        let activeSession = try await fetchLatestSession(clientID: clientID, statuses: [.active, .paused])
        let latestSession = try await fetchLatestSession(clientID: clientID, statuses: nil)

        return HydraSessionAwareness(
            activeSession: activeSession,
            latestSession: latestSession,
            updatedAt: Date()
        )
    }

    func sessionAwarenessStream(clientID: UUID) -> AsyncThrowingStream<HydraSessionAwareness, Error> {
        AsyncThrowingStream { continuation in
            let bridgeTask = Task {
                let clientProfileID = try await self.core.resolveClientProfileID(for: clientID)
                let channel = self.core.client.channel("hydrascan-sessions-\(clientProfileID.uuidString)")
                let changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "sessions",
                    filter: "client_id=eq.\(clientProfileID.uuidString)"
                )

                defer {
                    Task {
                        await self.core.client.removeChannel(channel)
                    }
                }

                do {
                    try await channel.subscribeWithError()
                    continuation.yield(try await self.fetchSessionAwareness(clientID: clientProfileID))

                    for await _ in changes {
                        if Task.isCancelled {
                            break
                        }

                        continuation.yield(try await self.fetchSessionAwareness(clientID: clientProfileID))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                bridgeTask.cancel()
            }
        }
    }

    func createOutcome(_ outcome: Outcome) async throws -> Outcome {
        let clientProfileID = try await core.resolveClientProfileID(for: outcome.clientID)
        guard let resolvedSession = try await resolveSession(for: outcome.sessionID, clientProfileID: clientProfileID) else {
            throw SupabaseServiceError.missingSession
        }

        let request = OutcomeRecorderRequest(
            sessionID: resolvedSession.id,
            recordedBy: outcome.recordedBy.rawValue,
            stiffnessBefore: outcome.stiffnessBefore,
            stiffnessAfter: outcome.stiffnessAfter ?? outcome.stiffnessBefore ?? 0,
            sorenessAfter: outcome.sorenessAfter,
            mobilityImproved: outcome.mobilityImproved?.asBool,
            sessionEffective: outcome.sessionEffective?.asBool,
            repeatIntent: outcome.repeatIntent == .noTryDifferent ? RepeatIntent.no.rawValue : (outcome.repeatIntent?.rawValue ?? RepeatIntent.maybe.rawValue),
            romAfter: outcome.romAfter.isEmpty ? nil : outcome.romAfter,
            notes: outcome.clientNotes?.nilIfBlank ?? outcome.practitionerNotes?.nilIfBlank
        )

        let response: OutcomeRecorderResponse
        do {
            response = try await core.client.functions.invoke(
                "outcome-recorder",
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            guard isMissingFunctionRoute(error) else {
                throw error
            }

            return try await insertOutcomeFallback(
                outcome,
                clientProfileID: clientProfileID,
                resolvedSession: resolvedSession
            )
        }

        guard response.success else {
            throw SupabaseServiceError.unavailable("Outcome submission did not complete successfully.")
        }

        var rows: [Outcome] = try await core.client
            .from("outcomes")
            .select()
            .eq("id", value: response.outcomeId.uuidString)
            .limit(1)
            .execute()
            .value

        guard var saved = rows.first else {
            throw SupabaseServiceError.unavailable("The outcome was recorded but could not be read back.")
        }

        let romDelta = try await computeROMDelta(
            romAfter: outcome.romAfter,
            assessmentID: resolvedSession.assessmentID
        )

        let patch = OutcomePatch(
            sorenessBefore: outcome.sorenessBefore,
            readinessImproved: outcome.readinessImproved?.rawValue,
            repeatIntent: outcome.repeatIntent == .noTryDifferent ? RepeatIntent.noTryDifferent.rawValue : nil,
            romDelta: romDelta,
            clientNotes: outcome.clientNotes?.nilIfBlank,
            practitionerNotes: outcome.practitionerNotes?.nilIfBlank
        )

        if !patch.isEmpty {
            rows = try await core.client
                .from("outcomes")
                .update(patch)
                .eq("id", value: saved.id.uuidString)
                .select()
                .limit(1)
                .execute()
                .value

            if let updated = rows.first {
                saved = updated
            }
        }

        return saved
    }

    func fetchLatestOutcome(clientID: UUID) async throws -> Outcome? {
        let clientProfileID = try await core.resolveClientProfileID(for: clientID)

        let rows: [Outcome] = try await core.client
            .from("outcomes")
            .select()
            .eq("client_id", value: clientProfileID.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func createCheckin(_ checkin: DailyCheckin) async throws -> DailyCheckin {
        let clientProfileID = try await core.resolveClientProfileID(for: checkin.clientID)
        let response: CheckinRecorderResponse
        do {
            response = try await core.client.functions.invoke(
                "checkin-recorder",
                options: FunctionInvokeOptions(
                    body: CheckinRecorderRequest(
                        checkinType: checkin.checkinType,
                        overallFeeling: checkin.overallFeeling,
                        targetRegions: checkin.targetRegions,
                        activitySinceLast: checkin.activitySinceLast?.nilIfBlank
                    )
                )
            )
        } catch {
            guard isMissingFunctionRoute(error) else {
                throw error
            }

            return try await insertCheckinFallback(checkin, clientProfileID: clientProfileID)
        }

        guard response.success else {
            throw SupabaseServiceError.unavailable("The check-in did not complete successfully.")
        }

        let rows: [DailyCheckin] = try await core.client
            .from("daily_checkins")
            .select()
            .eq("id", value: response.checkinId.uuidString)
            .eq("client_id", value: clientProfileID.uuidString)
            .limit(1)
            .execute()
            .value

        if let saved = rows.first {
            return saved
        }

        return DailyCheckin(
            id: response.checkinId,
            clientID: clientProfileID,
            clinicID: checkin.clinicID,
            checkinType: checkin.checkinType,
            overallFeeling: checkin.overallFeeling,
            targetRegions: checkin.targetRegions,
            activitySinceLast: checkin.activitySinceLast?.nilIfBlank,
            recoveryScore: response.recoveryScore,
            createdAt: checkin.createdAt,
            updatedAt: Date()
        )
    }

    func fetchRecentCheckins(clientID: UUID, limit: Int) async throws -> [DailyCheckin] {
        let clientProfileID = try await core.resolveClientProfileID(for: clientID)

        let rows: [DailyCheckin] = try await core.client
            .from("daily_checkins")
            .select()
            .eq("client_id", value: clientProfileID.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows
    }

    func fetchRecoveryScore(clientID: UUID) async throws -> RecoveryScore {
        let clientProfileID = try await core.resolveClientProfileID(for: clientID)

        do {
            let response: RecoveryScoreFunctionResponse = try await core.client.functions.invoke(
                "recovery-intelligence",
                options: FunctionInvokeOptions(
                    body: RecoveryIntelligenceActionRequest(
                        action: "recovery-score",
                        clientID: clientProfileID,
                        assessmentID: nil
                    )
                )
            )

            if response.success {
                let trend = try await fetchRecoveryTrend(clientID: clientProfileID)
                let current = Int(response.data.score.rounded())
                let previous = trend.dropLast().last?.value ?? max(current - 3, 0)
                return RecoveryScore(
                    current: current,
                    deltaFromLastWeek: current - previous,
                    updatedAt: Date(),
                    trend: trend
                )
            }
        } catch {
            // Fall through to local fallback if the edge function is unavailable.
        }

        let trend = try await fetchRecoveryTrend(clientID: clientProfileID)
        let graphRows = try await fetchRecoveryGraphScores(clientProfileID: clientProfileID, limit: 30)
        let recentOutcomes = try await fetchOutcomeInputs(clientProfileID: clientProfileID, limit: 5)
        let recentCheckins = try await fetchRecentCheckins(clientID: clientProfileID, limit: 7)
        let latestOutcome = try await fetchLatestOutcome(clientID: clientProfileID)
        let latestCheckin = recentCheckins.first

        let latestGraphDate = graphRows.first?.recordedAt
        let latestDataDate = [latestOutcome?.updatedAt ?? latestOutcome?.createdAt, latestCheckin?.updatedAt ?? latestCheckin?.createdAt]
            .compactMap { $0 }
            .max()

        if let latestGraphDate, latestDataDate == nil || latestGraphDate >= latestDataDate! {
            let orderedRows = graphRows.sorted(by: { $0.recordedAt < $1.recordedAt })
            let current = Int((orderedRows.last?.value ?? 0).rounded())
            let comparison = Int((orderedRows.dropLast().last?.value ?? Double(current)).rounded())

            return RecoveryScore(
                current: current,
                deltaFromLastWeek: current - comparison,
                updatedAt: orderedRows.last?.recordedAt ?? Date(),
                trend: trend.isEmpty ? buildTrend(from: orderedRows) : trend
            )
        }

        let current = try await computeRecoveryScoreValue(clientProfileID: clientProfileID)
        let previous = latestCheckin?.recoveryScore.flatMap { Int($0.rounded()) } ?? max(current - 3, 0)

        return RecoveryScore(
            current: current,
            deltaFromLastWeek: current - previous,
            updatedAt: latestDataDate ?? Date(),
            trend: trend.isEmpty ? (try await fallbackTrend(clientProfileID: clientProfileID)) : trend
        )
    }

    func fetchRecoveryTrend(clientID: UUID) async throws -> [RecoveryScoreTrendPoint] {
        let clientProfileID = try await core.resolveClientProfileID(for: clientID)
        let graphRows = try await fetchRecoveryGraphScores(clientProfileID: clientProfileID, limit: 30)

        if !graphRows.isEmpty {
            return buildTrend(from: graphRows.sorted(by: { $0.recordedAt < $1.recordedAt }))
        }

        return try await fallbackTrend(clientProfileID: clientProfileID)
    }

    private func resolveSession(for submittedSessionID: UUID, clientProfileID: UUID) async throws -> HydraSession? {
        if let directMatch = try await fetchSession(id: submittedSessionID) {
            return directMatch
        }

        let rowsByAssessment: [HydraSession] = try await core.client
            .from("sessions")
            .select()
            .eq("client_id", value: clientProfileID.uuidString)
            .eq("assessment_id", value: submittedSessionID.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if let session = rowsByAssessment.first {
            return session
        }

        let rowsByStatus: [HydraSession] = try await core.client
            .from("sessions")
            .select()
            .eq("client_id", value: clientProfileID.uuidString)
            .in("status", values: [HydraSessionStatus.active.rawValue, HydraSessionStatus.paused.rawValue, HydraSessionStatus.completed.rawValue, HydraSessionStatus.pending.rawValue])
            .order("created_at", ascending: false)
            .limit(5)
            .execute()
            .value

        return rowsByStatus.first
    }

    private func fetchSession(id: UUID) async throws -> HydraSession? {
        let rows: [HydraSession] = try await core.client
            .from("sessions")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    private func fetchAssessment(id: UUID) async throws -> Assessment? {
        let rows: [Assessment] = try await core.client
            .from("assessments")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    private func fetchRecoveryGraphScores(clientProfileID: UUID, limit: Int) async throws -> [RecoveryGraphScoreRow] {
        let rows: [RecoveryGraphScoreRow] = try await core.client
            .from("recovery_graph")
            .select("value, recorded_at")
            .eq("client_id", value: clientProfileID.uuidString)
            .eq("metric_type", value: "recovery_score")
            .order("recorded_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows
    }

    private func fetchOutcomeInputs(clientProfileID: UUID, limit: Int) async throws -> [(before: Int?, after: Int?)] {
        let rows: [Outcome] = try await core.client
            .from("outcomes")
            .select()
            .eq("client_id", value: clientProfileID.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.map { ($0.stiffnessBefore, $0.stiffnessAfter) }
    }

    private func computeROMDelta(romAfter: [String: Double], assessmentID: UUID?) async throws -> [String: Double]? {
        guard let assessmentID, !romAfter.isEmpty, let assessment = try await fetchAssessment(id: assessmentID) else {
            return nil
        }

        var delta: [String: Double] = [:]
        for (joint, afterValue) in romAfter {
            if let beforeValue = assessment.romValues[joint] {
                delta[joint] = afterValue - beforeValue
            }
        }

        return delta.isEmpty ? nil : delta
    }

    private func insertOutcomeFallback(
        _ outcome: Outcome,
        clientProfileID: UUID,
        resolvedSession: HydraSession
    ) async throws -> Outcome {
        let romDelta = try await computeROMDelta(
            romAfter: outcome.romAfter,
            assessmentID: resolvedSession.assessmentID
        )

        let fallbackOutcome = Outcome(
            id: outcome.id,
            sessionID: resolvedSession.id,
            clientID: clientProfileID,
            clinicID: resolvedSession.clinicID,
            recordedBy: outcome.recordedBy,
            recordedByUserID: outcome.recordedByUserID,
            stiffnessBefore: outcome.stiffnessBefore,
            stiffnessAfter: outcome.stiffnessAfter,
            sorenessBefore: outcome.sorenessBefore,
            sorenessAfter: outcome.sorenessAfter,
            mobilityImproved: outcome.mobilityImproved,
            sessionEffective: outcome.sessionEffective,
            readinessImproved: outcome.readinessImproved,
            repeatIntent: outcome.repeatIntent,
            romAfter: outcome.romAfter,
            romDelta: romDelta ?? outcome.romDelta,
            clientNotes: outcome.clientNotes?.nilIfBlank,
            practitionerNotes: outcome.practitionerNotes?.nilIfBlank,
            createdAt: outcome.createdAt,
            updatedAt: outcome.updatedAt
        )

        let rows: [Outcome] = try await core.client
            .from("outcomes")
            .insert(fallbackOutcome)
            .select()
            .limit(1)
            .execute()
            .value

        guard let saved = rows.first else {
            throw SupabaseServiceError.unavailable("The outcome was recorded but could not be read back.")
        }

        return saved
    }

    private func insertCheckinFallback(
        _ checkin: DailyCheckin,
        clientProfileID: UUID
    ) async throws -> DailyCheckin {
        let fallbackCheckin = DailyCheckin(
            id: checkin.id,
            clientID: clientProfileID,
            clinicID: checkin.clinicID,
            checkinType: checkin.checkinType,
            overallFeeling: checkin.overallFeeling,
            targetRegions: checkin.targetRegions,
            activitySinceLast: checkin.activitySinceLast?.nilIfBlank,
            recoveryScore: nil,
            createdAt: checkin.createdAt,
            updatedAt: checkin.updatedAt
        )

        var rows: [DailyCheckin] = try await core.client
            .from("daily_checkins")
            .insert(fallbackCheckin)
            .select()
            .limit(1)
            .execute()
            .value

        guard var saved = rows.first else {
            throw SupabaseServiceError.unavailable("The check-in was saved but could not be read back.")
        }

        let recomputedScore = try await computeRecoveryScoreValue(clientProfileID: clientProfileID)
        rows = try await core.client
            .from("daily_checkins")
            .update(CheckinScorePatch(recoveryScore: Double(recomputedScore)))
            .eq("id", value: saved.id.uuidString)
            .select()
            .limit(1)
            .execute()
            .value

        if let updated = rows.first {
            saved = updated
        } else {
            saved.recoveryScore = Double(recomputedScore)
        }

        return saved
    }

    private func computeRecoveryScoreValue(clientProfileID: UUID) async throws -> Int {
        let outcomeInputs = try await fetchOutcomeInputs(clientProfileID: clientProfileID, limit: 5)
        let assessmentSignals = try await fetchAssessmentSignals(clientProfileID: clientProfileID, limit: 3)
        let recentCheckins = try await fetchRecentCheckins(clientID: clientProfileID, limit: 7)
        let profile = try await core.fetchClientProfile(id: clientProfileID)
        let adherence = try await computeSessionAdherence(clientProfileID: clientProfileID)

        var outcomeTrend = 0.0
        if !outcomeInputs.isEmpty {
            let factors = outcomeInputs.map { before, after -> Double in
                let beforeValue = Double(before ?? 0)
                let afterValue = Double(after ?? 0)
                return ((beforeValue - afterValue) / 10.0) * 20.0
            }

            outcomeTrend = clamp(factors.reduce(0, +) / Double(factors.count), min: -20, max: 20)
        }

        var checkinTrend = 0.0
        if !recentCheckins.isEmpty {
            let averageFeeling = recentCheckins.map(\.overallFeeling).reduce(0, +)
            checkinTrend = clamp((Double(averageFeeling) / Double(recentCheckins.count) - 3.0) * 5.0, min: -10, max: 10)
        }

        var assessmentSignal = 0.0
        if !assessmentSignals.isEmpty {
            let movementQualityValues = assessmentSignals.flatMap { signal in
                signal.movementQualityScores.values.map { value in
                    value > 1 ? value / 100.0 : value
                }
            }
            let asymmetryValues = assessmentSignals.flatMap { signal in
                signal.asymmetryScores.values
            }
            let gaitStressValues = assessmentSignals.flatMap { signal in
                signal.gaitMetrics.values
            }

            if !movementQualityValues.isEmpty {
                let averageQuality = movementQualityValues.reduce(0, +) / Double(movementQualityValues.count)
                assessmentSignal += clamp((averageQuality - 0.5) * 12.0, min: -6, max: 6)
            }

            if !asymmetryValues.isEmpty {
                let averageAsymmetry = asymmetryValues.reduce(0, +) / Double(asymmetryValues.count)
                let symmetryScore = clamp(1.0 - (averageAsymmetry / 100.0), min: 0, max: 1)
                assessmentSignal += clamp((symmetryScore - 0.5) * 8.0, min: -4, max: 4)
            }

            if !gaitStressValues.isEmpty {
                let averageGaitStress = gaitStressValues.reduce(0, +) / Double(gaitStressValues.count)
                let gaitScore = clamp(1.0 - (averageGaitStress / 100.0), min: 0, max: 1)
                assessmentSignal += clamp((gaitScore - 0.5) * 6.0, min: -3, max: 3)
            }

            assessmentSignal = clamp(assessmentSignal, min: -10, max: 10)
        }

        var wearableAdjustment = 0.0
        if let hrv = profile?.wearableHRV {
            if hrv > 50 {
                wearableAdjustment += 5
            } else if hrv < 30 {
                wearableAdjustment -= 5
            }
        }

        if let sleepScore = profile?.wearableSleepScore {
            if sleepScore > 70 {
                wearableAdjustment += 5
            } else if sleepScore < 50 {
                wearableAdjustment -= 5
            }
        }

        wearableAdjustment = clamp(wearableAdjustment, min: -10, max: 10)
        let adherenceBonus = clamp(adherence * 10, min: 0, max: 10)
        let rawScore = clamp(
            50 + outcomeTrend + checkinTrend + assessmentSignal + wearableAdjustment + adherenceBonus,
            min: 0,
            max: 100
        )

        return Int(rawScore.rounded())
    }

    private func computeSessionAdherence(clientProfileID: UUID) async throws -> Double {
        let allSessions: [HydraSession] = try await core.client
            .from("sessions")
            .select()
            .eq("client_id", value: clientProfileID.uuidString)
            .order("created_at", ascending: false)
            .limit(30)
            .execute()
            .value

        guard !allSessions.isEmpty else {
            return 0
        }

        let completedCount = allSessions.filter { $0.status == .completed }.count
        return Double(completedCount) / Double(allSessions.count)
    }

    private func fetchAssessmentSignals(
        clientProfileID: UUID,
        limit: Int
    ) async throws -> [(movementQualityScores: [String: Double], asymmetryScores: [String: Double], gaitMetrics: [String: Double])] {
        struct AssessmentSignalRow: Decodable {
            let movementQualityScores: [String: Double]
            let asymmetryScores: [String: Double]
            let gaitMetrics: [String: Double]?

            enum CodingKeys: String, CodingKey {
                case movementQualityScores = "movement_quality_scores"
                case asymmetryScores = "asymmetry_scores"
                case gaitMetrics = "gait_metrics"
            }
        }

        let rows: [AssessmentSignalRow] = try await core.client
            .from("assessments")
            .select("movement_quality_scores, asymmetry_scores, gait_metrics")
            .eq("client_id", value: clientProfileID.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.map { ($0.movementQualityScores, $0.asymmetryScores, $0.gaitMetrics ?? [:]) }
    }

    private func fallbackTrend(clientProfileID: UUID) async throws -> [RecoveryScoreTrendPoint] {
        let recentCheckins = try await fetchRecentCheckins(clientID: clientProfileID, limit: 5)
        if recentCheckins.isEmpty {
            return [
                RecoveryScoreTrendPoint(dayLabel: "Mon", value: 72),
                RecoveryScoreTrendPoint(dayLabel: "Tue", value: 74),
                RecoveryScoreTrendPoint(dayLabel: "Wed", value: 77),
                RecoveryScoreTrendPoint(dayLabel: "Thu", value: 79),
                RecoveryScoreTrendPoint(dayLabel: "Fri", value: 82),
            ]
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "E"

        return recentCheckins
            .prefix(5)
            .reversed()
            .map { checkin in
                let baseValue = checkin.recoveryScore.flatMap { Int($0.rounded()) } ?? max(0, min(100, checkin.overallFeeling * 20))
                return RecoveryScoreTrendPoint(
                    dayLabel: formatter.string(from: checkin.updatedAt ?? checkin.createdAt),
                    value: baseValue
                )
            }
    }

    private func buildTrend(from rows: [RecoveryGraphScoreRow]) -> [RecoveryScoreTrendPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"

        return Array(rows.suffix(7)).map { row in
            RecoveryScoreTrendPoint(
                dayLabel: formatter.string(from: row.recordedAt),
                value: Int(row.value.rounded())
            )
        }
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }

    private func isMissingFunctionRoute(_ error: Error) -> Bool {
        if let functionsError = error as? FunctionsError,
           case let .httpError(code, _) = functionsError {
            return code == 404
        }

        return error.localizedDescription.contains("Edge Function returned a non-2xx status code: 404")
    }

    func claimClinicInvite(inviteCode: String, fullName: String) async throws -> HydraSessionContext {
        let response: ClaimClinicInviteResponse = try await core.client.functions.invoke(
            "claim-clinic-invite",
            options: FunctionInvokeOptions(
                body: ClaimClinicInviteRequest(
                    inviteCode: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines),
                    fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        )

        guard response.success else {
            throw SupabaseServiceError.incompleteOnboarding
        }

        let session = try await core.client.auth.session
        return try await core.loadSessionContext(from: session.user, allowProvisioningRetry: true)
    }

    func resetSessionContext() async {
        await HydraSessionStore.shared.update(nil)
    }
}
#else
final class LiveSupabaseService: SupabaseServiceProtocol {
    init() throws {
        throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.")
    }

    func currentSessionContext() async -> HydraSessionContext? { nil }
    func ensureClientProfile(for user: HydraUser) async throws -> ClientProfile { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func fetchClientProfile(userID: UUID) async throws -> ClientProfile { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func updateClientProfile(_ profile: ClientProfile) async throws -> ClientProfile { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func createAssessment(_ assessment: Assessment) async throws -> Assessment { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func fetchAssessments(clientID: UUID) async throws -> [Assessment] { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func fetchLatestAssessment(clientID: UUID) async throws -> Assessment? { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func fetchSessions(clientID: UUID, limit: Int) async throws -> [HydraSession] { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func fetchLatestSession(clientID: UUID, statuses: [HydraSessionStatus]?) async throws -> HydraSession? { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func fetchSessionAwareness(clientID: UUID) async throws -> HydraSessionAwareness { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func sessionAwarenessStream(clientID: UUID) -> AsyncThrowingStream<HydraSessionAwareness, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: SupabaseServiceError.unavailable("Supabase is unavailable in this build."))
        }
    }
    func createOutcome(_ outcome: Outcome) async throws -> Outcome { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func fetchLatestOutcome(clientID: UUID) async throws -> Outcome? { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func createCheckin(_ checkin: DailyCheckin) async throws -> DailyCheckin { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func fetchRecentCheckins(clientID: UUID, limit: Int) async throws -> [DailyCheckin] { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func fetchRecoveryScore(clientID: UUID) async throws -> RecoveryScore { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func fetchRecoveryTrend(clientID: UUID) async throws -> [RecoveryScoreTrendPoint] { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func claimClinicInvite(inviteCode: String, fullName: String) async throws -> HydraSessionContext { throw SupabaseServiceError.unavailable("Supabase is unavailable in this build.") }
    func resetSessionContext() async {}
}
#endif

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension TriStateChoice {
    var asBool: Bool? {
        switch self {
        case .yes:
            return true
        case .no:
            return false
        case .maybe:
            return nil
        }
    }
}
