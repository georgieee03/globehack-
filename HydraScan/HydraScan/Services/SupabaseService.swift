import Foundation

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

actor LiveSupabaseService: SupabaseServiceProtocol {
    private let urlSession: URLSession
    private let userDefaults: UserDefaults
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var profilesByUserID: [UUID: ClientProfile] = [:]
    private var profilesByProfileID: [UUID: ClientProfile] = [:]

    init(
        urlSession: URLSession = .shared,
        userDefaults: UserDefaults = .standard
    ) throws {
        guard HydraScanConstants.usesLiveServices else {
            throw SupabaseServiceError.unavailable("Set SUPABASE_URL and SUPABASE_ANON_KEY before using the live service.")
        }

        self.urlSession = urlSession
        self.userDefaults = userDefaults

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            guard let date = decodeSupabaseServiceDate(value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date string \(value)")
            }

            return date
        }
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.iso8601String)
        }
        self.encoder = encoder
    }

    func ensureClientProfile(for user: HydraUser) async throws -> ClientProfile {
        if let profile = try await fetchClientProfileIfExists(userID: user.id) {
            return profile
        }

        if user.role == .client {
            throw SupabaseServiceError.unavailable(
                "Your account is signed in, but your client profile is not ready yet. Ask your clinic to confirm the onboarding invite if this keeps happening."
            )
        }

        guard let clinicID = user.clinicID else {
            throw SupabaseServiceError.unavailable("This account is missing a clinic assignment.")
        }

        let payload = ClientProfileWriteRow(
            userID: user.id,
            clinicID: clinicID,
            primaryRegions: [],
            recoverySignals: [:],
            goals: [],
            activityContext: nil,
            sensitivities: [],
            notes: nil,
            wearableHRV: nil,
            wearableStrain: nil,
            wearableSleepScore: nil,
            wearableLastSync: nil
        )

        let rows: [ClientProfileRow] = try await requestJSON(
            path: "/rest/v1/client_profiles",
            method: .post,
            bodyData: try encodeBody([payload]),
            preferRepresentation: true,
            responseType: [ClientProfileRow].self
        )

        guard let row = rows.first else {
            throw SupabaseServiceError.unavailable("Supabase did not return the new client profile.")
        }

        return cache(row.clientProfile)
    }

    func fetchClientProfile(userID: UUID) async throws -> ClientProfile {
        if let cached = profilesByUserID[userID] {
            return cached
        }

        guard let profile = try await fetchClientProfileIfExists(userID: userID) else {
            throw SupabaseServiceError.missingProfile
        }

        return profile
    }

    func updateClientProfile(_ profile: ClientProfile) async throws -> ClientProfile {
        let existing = try await resolveClientProfile(from: profile.id, fallbackUserID: profile.userID)

        let payload = ClientProfileWriteRow(
            userID: existing.userID,
            clinicID: existing.clinicID ?? profile.clinicID,
            primaryRegions: profile.primaryRegions,
            recoverySignals: profile.recoverySignalsByRegion,
            goals: profile.goals,
            activityContext: profile.activityContext?.nilIfEmpty,
            sensitivities: profile.sensitivities,
            notes: profile.notes?.nilIfEmpty,
            wearableHRV: profile.wearableHRV,
            wearableStrain: profile.wearableStrain,
            wearableSleepScore: profile.wearableSleepScore,
            wearableLastSync: profile.wearableLastSync
        )

        let rows: [ClientProfileRow] = try await requestJSON(
            path: "/rest/v1/client_profiles",
            method: .patch,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(existing.id.uuidString)"),
                URLQueryItem(name: "select", value: clientProfileSelect),
            ],
            bodyData: try encodeBody(payload),
            preferRepresentation: true,
            responseType: [ClientProfileRow].self
        )

        guard let row = rows.first else {
            throw SupabaseServiceError.unavailable("Supabase did not return the updated client profile.")
        }

        return cache(row.clientProfile)
    }

    func createAssessment(_ assessment: Assessment) async throws -> Assessment {
        let profile = try await resolveClientProfile(from: assessment.clientID)

        let payload = AssessmentWriteRow(
            id: assessment.id,
            clientID: profile.id,
            clinicID: profile.clinicID ?? assessment.clinicID,
            practitionerID: assessment.practitionerID,
            assessmentType: assessment.assessmentType,
            quickPoseData: assessment.quickPoseData,
            romValues: assessment.romValues.isEmpty ? nil : assessment.romValues,
            asymmetryScores: assessment.asymmetryScores.isEmpty ? nil : assessment.asymmetryScores,
            movementQualityScores: assessment.movementQualityScores.isEmpty ? nil : assessment.movementQualityScores,
            gaitMetrics: assessment.gaitMetrics.isEmpty ? nil : assessment.gaitMetrics,
            heartRate: assessment.heartRate,
            breathRate: assessment.breathRate,
            hrvRMSSD: assessment.hrvRMSSD,
            bodyZones: assessment.bodyZones.isEmpty ? nil : assessment.bodyZones,
            recoveryGoal: assessment.recoveryGoal,
            subjectiveBaseline: assessment.subjectiveBaseline,
            recoveryMap: assessment.recoveryMap,
            recoveryGraphDelta: assessment.recoveryGraphDelta.isEmpty ? nil : assessment.recoveryGraphDelta,
            createdAt: assessment.createdAt
        )

        let rows: [AssessmentRow] = try await requestJSON(
            path: "/rest/v1/assessments",
            method: .post,
            bodyData: try encodeBody([payload]),
            preferRepresentation: true,
            responseType: [AssessmentRow].self
        )

        guard let row = rows.first else {
            throw SupabaseServiceError.unavailable("Supabase did not return the saved assessment.")
        }

        return row.assessment
    }

    func fetchAssessments(clientID: UUID) async throws -> [Assessment] {
        let resolvedProfileID = try await resolveClientProfileID(from: clientID)
        let rows: [AssessmentRow] = try await requestJSON(
            path: "/rest/v1/assessments",
            method: .get,
            queryItems: [
                URLQueryItem(name: "client_id", value: "eq.\(resolvedProfileID.uuidString)"),
                URLQueryItem(name: "select", value: assessmentSelect),
                URLQueryItem(name: "order", value: "created_at.desc"),
            ],
            responseType: [AssessmentRow].self
        )

        return rows.map(\.assessment)
    }

    func fetchLatestAssessment(clientID: UUID) async throws -> Assessment? {
        let resolvedProfileID = try await resolveClientProfileID(from: clientID)
        let rows: [AssessmentRow] = try await requestJSON(
            path: "/rest/v1/assessments",
            method: .get,
            queryItems: [
                URLQueryItem(name: "client_id", value: "eq.\(resolvedProfileID.uuidString)"),
                URLQueryItem(name: "select", value: assessmentSelect),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "1"),
            ],
            responseType: [AssessmentRow].self
        )

        return rows.first?.assessment
    }

    func createOutcome(_ outcome: Outcome) async throws -> Outcome {
        let profile = try await resolveClientProfile(from: outcome.clientID)
        let sessionID = try await resolveSessionID(forOutcomeSessionCandidate: outcome.sessionID, clientProfileID: profile.id)
        let authUserID = outcome.recordedByUserID ?? try currentAuthUserID()

        let payload = OutcomeWriteRow(
            id: outcome.id,
            sessionID: sessionID,
            clientID: profile.id,
            clinicID: profile.clinicID ?? outcome.clinicID,
            recordedBy: outcome.recordedBy,
            recordedByUserID: authUserID,
            stiffnessBefore: outcome.stiffnessBefore,
            stiffnessAfter: outcome.stiffnessAfter,
            sorenessBefore: outcome.sorenessBefore,
            sorenessAfter: outcome.sorenessAfter,
            mobilityImproved: outcome.mobilityImproved,
            sessionEffective: outcome.sessionEffective,
            readinessImproved: outcome.readinessImproved,
            repeatIntent: outcome.repeatIntent,
            romAfter: outcome.romAfter.isEmpty ? nil : outcome.romAfter,
            romDelta: outcome.romDelta.isEmpty ? nil : outcome.romDelta,
            clientNotes: outcome.clientNotes?.nilIfEmpty,
            practitionerNotes: outcome.practitionerNotes?.nilIfEmpty,
            createdAt: outcome.createdAt
        )

        let rows: [OutcomeRow] = try await requestJSON(
            path: "/rest/v1/outcomes",
            method: .post,
            bodyData: try encodeBody([payload]),
            preferRepresentation: true,
            responseType: [OutcomeRow].self
        )

        guard let row = rows.first else {
            throw SupabaseServiceError.unavailable("Supabase did not return the saved outcome.")
        }

        return row.outcome
    }

    func fetchLatestOutcome(clientID: UUID) async throws -> Outcome? {
        let resolvedProfileID = try await resolveClientProfileID(from: clientID)
        let rows: [OutcomeRow] = try await requestJSON(
            path: "/rest/v1/outcomes",
            method: .get,
            queryItems: [
                URLQueryItem(name: "client_id", value: "eq.\(resolvedProfileID.uuidString)"),
                URLQueryItem(name: "select", value: outcomeSelect),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "1"),
            ],
            responseType: [OutcomeRow].self
        )

        return rows.first?.outcome
    }

    func createCheckin(_ checkin: DailyCheckin) async throws -> DailyCheckin {
        let profile = try await resolveClientProfile(from: checkin.clientID)

        let payload = DailyCheckinWriteRow(
            id: checkin.id,
            clientID: profile.id,
            clinicID: profile.clinicID ?? checkin.clinicID,
            checkinType: checkin.checkinType,
            overallFeeling: checkin.overallFeeling,
            targetRegions: checkin.targetRegions,
            activitySinceLast: checkin.activitySinceLast?.nilIfEmpty,
            recoveryScore: checkin.recoveryScore,
            createdAt: checkin.createdAt
        )

        let rows: [DailyCheckinRow] = try await requestJSON(
            path: "/rest/v1/daily_checkins",
            method: .post,
            bodyData: try encodeBody([payload]),
            preferRepresentation: true,
            responseType: [DailyCheckinRow].self
        )

        guard let row = rows.first else {
            throw SupabaseServiceError.unavailable("Supabase did not return the saved check-in.")
        }

        return row.checkin
    }

    func fetchRecentCheckins(clientID: UUID, limit: Int) async throws -> [DailyCheckin] {
        let resolvedProfileID = try await resolveClientProfileID(from: clientID)
        let rows = try await fetchRecentCheckins(clientProfileID: resolvedProfileID, limit: limit)
        return rows.map(\.checkin)
    }

    func fetchRecoveryScore(clientID: UUID) async throws -> RecoveryScore {
        let profile = try await resolveClientProfile(from: clientID)

        if let score = try await fetchRecoveryScoreFromGraph(clientProfileID: profile.id) {
            return score
        }

        return try await buildFallbackRecoveryScore(clientProfile: profile)
    }

    func fetchRecoveryTrend(clientID: UUID) async throws -> [RecoveryScoreTrendPoint] {
        let profile = try await resolveClientProfile(from: clientID)

        let graphRows: [RecoveryGraphScoreRow] = try await requestJSON(
            path: "/rest/v1/recovery_graph",
            method: .get,
            queryItems: [
                URLQueryItem(name: "client_id", value: "eq.\(profile.id.uuidString)"),
                URLQueryItem(name: "metric_type", value: "eq.recovery_score"),
                URLQueryItem(name: "body_region", value: "eq.overall"),
                URLQueryItem(name: "select", value: "value,recorded_at"),
                URLQueryItem(name: "order", value: "recorded_at.desc"),
                URLQueryItem(name: "limit", value: "7"),
            ],
            responseType: [RecoveryGraphScoreRow].self
        )

        if !graphRows.isEmpty {
            return buildTrend(from: graphRows)
        }

        let checkins = try await fetchRecentCheckins(clientProfileID: profile.id, limit: 7)
        if !checkins.isEmpty {
            return buildTrend(from: checkins)
        }

        let outcomes = try await fetchOutcomeTrendRows(clientProfileID: profile.id, limit: 7)
        if !outcomes.isEmpty {
            return buildTrend(from: outcomes)
        }

        return []
    }

    private func fetchClientProfileIfExists(userID: UUID) async throws -> ClientProfile? {
        let rows: [ClientProfileRow] = try await requestJSON(
            path: "/rest/v1/client_profiles",
            method: .get,
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"),
                URLQueryItem(name: "select", value: clientProfileSelect),
                URLQueryItem(name: "limit", value: "1"),
            ],
            responseType: [ClientProfileRow].self
        )

        guard let row = rows.first else {
            return nil
        }

        return cache(row.clientProfile)
    }

    private func fetchClientProfileByID(_ profileID: UUID) async throws -> ClientProfile? {
        if let cached = profilesByProfileID[profileID] {
            return cached
        }

        let rows: [ClientProfileRow] = try await requestJSON(
            path: "/rest/v1/client_profiles",
            method: .get,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(profileID.uuidString)"),
                URLQueryItem(name: "select", value: clientProfileSelect),
                URLQueryItem(name: "limit", value: "1"),
            ],
            responseType: [ClientProfileRow].self
        )

        guard let row = rows.first else {
            return nil
        }

        return cache(row.clientProfile)
    }

    private func resolveClientProfile(from candidateID: UUID, fallbackUserID: UUID? = nil) async throws -> ClientProfile {
        if let cached = profilesByProfileID[candidateID] ?? profilesByUserID[candidateID] {
            return cached
        }

        if let profile = try await fetchClientProfileByID(candidateID) {
            return profile
        }

        if let profile = try await fetchClientProfileIfExists(userID: candidateID) {
            return profile
        }

        if let fallbackUserID, let profile = try await fetchClientProfileIfExists(userID: fallbackUserID) {
            return profile
        }

        throw SupabaseServiceError.missingProfile
    }

    private func resolveClientProfileID(from candidateID: UUID) async throws -> UUID {
        try await resolveClientProfile(from: candidateID).id
    }

    private func resolveSessionID(forOutcomeSessionCandidate candidateID: UUID, clientProfileID: UUID) async throws -> UUID {
        if try await sessionExists(id: candidateID, clientProfileID: clientProfileID) {
            return candidateID
        }

        if let session = try await sessionLinkedToAssessment(id: candidateID, clientProfileID: clientProfileID) {
            return session.id
        }

        throw SupabaseServiceError.unavailable(
            "Post-session feedback needs a real session record from the clinic workflow before it can sync from iOS."
        )
    }

    private func sessionExists(id: UUID, clientProfileID: UUID) async throws -> Bool {
        let rows: [SessionLookupRow] = try await requestJSON(
            path: "/rest/v1/sessions",
            method: .get,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
                URLQueryItem(name: "client_id", value: "eq.\(clientProfileID.uuidString)"),
                URLQueryItem(name: "select", value: "id"),
                URLQueryItem(name: "limit", value: "1"),
            ],
            responseType: [SessionLookupRow].self
        )

        return !rows.isEmpty
    }

    private func sessionLinkedToAssessment(id: UUID, clientProfileID: UUID) async throws -> SessionLookupRow? {
        let rows: [SessionLookupRow] = try await requestJSON(
            path: "/rest/v1/sessions",
            method: .get,
            queryItems: [
                URLQueryItem(name: "assessment_id", value: "eq.\(id.uuidString)"),
                URLQueryItem(name: "client_id", value: "eq.\(clientProfileID.uuidString)"),
                URLQueryItem(name: "select", value: "id"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "1"),
            ],
            responseType: [SessionLookupRow].self
        )

        return rows.first
    }

    private func fetchRecentCheckins(clientProfileID: UUID, limit: Int) async throws -> [DailyCheckinRow] {
        let safeLimit = max(1, min(limit, 60))

        return try await requestJSON(
            path: "/rest/v1/daily_checkins",
            method: .get,
            queryItems: [
                URLQueryItem(name: "client_id", value: "eq.\(clientProfileID.uuidString)"),
                URLQueryItem(name: "select", value: checkinSelect),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "\(safeLimit)"),
            ],
            responseType: [DailyCheckinRow].self
        )
    }

    private func fetchOutcomeTrendRows(clientProfileID: UUID, limit: Int) async throws -> [OutcomeTrendRow] {
        let safeLimit = max(1, min(limit, 20))

        return try await requestJSON(
            path: "/rest/v1/outcomes",
            method: .get,
            queryItems: [
                URLQueryItem(name: "client_id", value: "eq.\(clientProfileID.uuidString)"),
                URLQueryItem(name: "select", value: "stiffness_before,stiffness_after,created_at"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "\(safeLimit)"),
            ],
            responseType: [OutcomeTrendRow].self
        )
    }

    private func fetchRecoveryScoreFromGraph(clientProfileID: UUID) async throws -> RecoveryScore? {
        let rows: [RecoveryGraphScoreRow] = try await requestJSON(
            path: "/rest/v1/recovery_graph",
            method: .get,
            queryItems: [
                URLQueryItem(name: "client_id", value: "eq.\(clientProfileID.uuidString)"),
                URLQueryItem(name: "metric_type", value: "eq.recovery_score"),
                URLQueryItem(name: "body_region", value: "eq.overall"),
                URLQueryItem(name: "select", value: "value,recorded_at"),
                URLQueryItem(name: "order", value: "recorded_at.desc"),
                URLQueryItem(name: "limit", value: "7"),
            ],
            responseType: [RecoveryGraphScoreRow].self
        )

        guard let latest = rows.first else {
            return nil
        }

        let trend = buildTrend(from: rows)
        let previous = rows.last?.value ?? latest.value

        return RecoveryScore(
            current: Int(latest.value.rounded()),
            deltaFromLastWeek: Int((latest.value - previous).rounded()),
            updatedAt: latest.recordedAt,
            trend: trend
        )
    }

    private func buildFallbackRecoveryScore(clientProfile: ClientProfile) async throws -> RecoveryScore {
        let checkins = try await fetchRecentCheckins(clientProfileID: clientProfile.id, limit: 7)
        let outcomes = try await fetchOutcomeTrendRows(clientProfileID: clientProfile.id, limit: 5)

        var rawScore = 50.0

        let reductions = outcomes.compactMap { row -> Double? in
            guard let before = row.stiffnessBefore, let after = row.stiffnessAfter else {
                return nil
            }

            return Double(before - after) / 10.0
        }

        if !reductions.isEmpty {
            let averageReduction = reductions.reduce(0, +) / Double(reductions.count)
            rawScore += averageReduction * 40
        }

        if !checkins.isEmpty {
            let averageFeeling = Double(checkins.reduce(0) { $0 + $1.overallFeeling }) / Double(checkins.count)
            rawScore += (averageFeeling - 3) * 5
        }

        if let sleepScore = clientProfile.wearableSleepScore {
            rawScore += (sleepScore - 50) / 10
        }

        if let hrv = clientProfile.wearableHRV {
            rawScore += max(-5, min(5, (hrv - 50) / 10))
        }

        let current = Int(max(0, min(100, rawScore)).rounded())
        let trend = !checkins.isEmpty ? buildTrend(from: checkins) : buildTrend(from: outcomes)
        let previous = trend.dropLast().last?.value ?? current
        let updatedAt = checkins.first?.createdAt ?? outcomes.first?.createdAt ?? clientProfile.updatedAt

        return RecoveryScore(
            current: current,
            deltaFromLastWeek: current - previous,
            updatedAt: updatedAt,
            trend: trend
        )
    }

    @discardableResult
    private func cache(_ profile: ClientProfile) -> ClientProfile {
        profilesByUserID[profile.userID] = profile
        profilesByProfileID[profile.id] = profile
        return profile
    }

    private func currentAuthUserID() throws -> UUID {
        guard let storedSession = loadStoredSession(), let authUserID = storedSession.authUserID else {
            throw SupabaseServiceError.missingUser
        }

        return authUserID
    }

    private func encodeBody<Body: Encodable>(_ body: Body) throws -> Data {
        try encoder.encode(body)
    }

    private func requestJSON<ResponseType: Decodable>(
        path: String,
        method: RESTHTTPMethod,
        queryItems: [URLQueryItem] = [],
        bodyData: Data? = nil,
        preferRepresentation: Bool = false,
        responseType: ResponseType.Type
    ) async throws -> ResponseType {
        let accessToken = try await authenticatedAccessToken()
        return try await requestJSON(
            path: path,
            method: method,
            queryItems: queryItems,
            bodyData: bodyData,
            accessToken: accessToken,
            preferRepresentation: preferRepresentation,
            responseType: responseType
        )
    }

    private func requestJSON<ResponseType: Decodable>(
        path: String,
        method: RESTHTTPMethod,
        queryItems: [URLQueryItem] = [],
        bodyData: Data? = nil,
        accessToken: String?,
        preferRepresentation: Bool = false,
        responseType: ResponseType.Type
    ) async throws -> ResponseType {
        guard
            var components = URLComponents(
                url: try requestURL(forPath: path),
                resolvingAgainstBaseURL: true
            )
        else {
            throw SupabaseServiceError.unavailable("Supabase request URL could not be built.")
        }

        if !queryItems.isEmpty {
            let existingQueryItems = components.queryItems ?? []
            components.queryItems = existingQueryItems + queryItems
        }

        guard let url = components.url else {
            throw SupabaseServiceError.unavailable("Supabase request URL could not be built.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(HydraScanConstants.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if preferRepresentation {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }

        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseServiceError.unavailable("Supabase did not return a valid HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = parseSupabaseServiceErrorMessage(from: data)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw SupabaseServiceError.unavailable(message)
        }

        return try decoder.decode(ResponseType.self, from: data)
    }

    private func authenticatedAccessToken() async throws -> String {
        guard let storedSession = loadStoredSession() else {
            throw SupabaseServiceError.missingUser
        }

        if storedSession.expiresAt > Date().addingTimeInterval(30), !storedSession.accessToken.isEmpty {
            return storedSession.accessToken
        }

        let refreshed = try await refreshStoredSession(storedSession)
        return refreshed.accessToken
    }

    private func refreshStoredSession(_ storedSession: LiveServiceStoredSession) async throws -> LiveServiceStoredSession {
        let response: LiveServiceRefreshResponse = try await requestJSON(
            path: "/auth/v1/token?grant_type=refresh_token",
            method: .post,
            bodyData: try encodeBody(["refresh_token": storedSession.refreshToken]),
            accessToken: nil,
            responseType: LiveServiceRefreshResponse.self
        )

        let refreshed = LiveServiceStoredSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            authUserID: response.user?.id ?? storedSession.authUserID
        )

        saveStoredSession(refreshed)
        return refreshed
    }

    private func requestURL(forPath path: String) throws -> URL {
        guard let baseURL = HydraScanConstants.supabaseURL else {
            throw SupabaseServiceError.unavailable("Supabase URL is not configured.")
        }

        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw SupabaseServiceError.unavailable("Supabase URL is not configured.")
        }

        return url
    }

    private func loadStoredSession() -> LiveServiceStoredSession? {
        guard let data = userDefaults.data(forKey: HydraScanConstants.sessionStorageKey) else {
            return nil
        }

        return try? decoder.decode(LiveServiceStoredSession.self, from: data)
    }

    private func saveStoredSession(_ session: LiveServiceStoredSession) {
        guard let data = try? encoder.encode(session) else {
            return
        }

        userDefaults.set(data, forKey: HydraScanConstants.sessionStorageKey)
    }

    private func buildTrend(from rows: [RecoveryGraphScoreRow]) -> [RecoveryScoreTrendPoint] {
        rows
            .suffix(7)
            .reversed()
            .map { row in
                RecoveryScoreTrendPoint(
                    dayLabel: supabaseTrendDayFormatter.string(from: row.recordedAt),
                    value: Int(row.value.rounded())
                )
            }
    }

    private func buildTrend(from rows: [DailyCheckinRow]) -> [RecoveryScoreTrendPoint] {
        rows
            .suffix(7)
            .reversed()
            .map { row in
                let fallbackScore = row.overallFeeling * 20
                let value = Int((row.recoveryScore ?? Double(fallbackScore)).rounded())
                return RecoveryScoreTrendPoint(
                    dayLabel: supabaseTrendDayFormatter.string(from: row.createdAt),
                    value: max(0, min(100, value))
                )
            }
    }

    private func buildTrend(from rows: [OutcomeTrendRow]) -> [RecoveryScoreTrendPoint] {
        rows
            .suffix(7)
            .reversed()
            .map { row in
                let value = max(0, min(100, 100 - ((row.stiffnessAfter ?? 5) * 10)))
                return RecoveryScoreTrendPoint(
                    dayLabel: supabaseTrendDayFormatter.string(from: row.createdAt),
                    value: value
                )
            }
    }
}

private enum RESTHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
}

private let clientProfileSelect =
    "id,user_id,clinic_id,primary_regions,recovery_signals,goals,activity_context,sensitivities,notes,wearable_hrv,wearable_strain,wearable_sleep_score,wearable_last_sync,created_at,updated_at"
private let assessmentSelect =
    "id,client_id,clinic_id,practitioner_id,assessment_type,quickpose_data,rom_values,asymmetry_scores,movement_quality_scores,gait_metrics,heart_rate,breath_rate,hrv_rmssd,body_zones,recovery_goal,subjective_baseline,recovery_map,recovery_graph_delta,created_at"
private let outcomeSelect =
    "id,session_id,client_id,clinic_id,recorded_by,recorded_by_user_id,stiffness_before,stiffness_after,soreness_before,soreness_after,mobility_improved,session_effective,readiness_improved,repeat_intent,rom_after,rom_delta,client_notes,practitioner_notes,created_at"
private let checkinSelect =
    "id,client_id,clinic_id,checkin_type,overall_feeling,target_regions,activity_since_last,recovery_score,created_at,updated_at"
private let supabaseServiceISO8601WithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()
private let supabaseServiceISO8601Standard: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()
private let supabaseServiceCalendarDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()
private let supabaseTrendDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "E"
    return formatter
}()

private struct LiveServiceStoredSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let authUserID: UUID?
}

private struct LiveServiceRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: LiveServiceAuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

private struct LiveServiceAuthUser: Codable {
    let id: UUID
}

private struct ClientProfileRow: Codable {
    let id: UUID
    let userID: UUID
    let clinicID: UUID?
    let primaryRegions: [BodyRegion]
    let recoverySignals: [String: RecoverySignalValue]
    let goals: [RecoveryGoal]
    let activityContext: String?
    let sensitivities: [String]
    let notes: String?
    let wearableHRV: Double?
    let wearableStrain: Double?
    let wearableSleepScore: Double?
    let wearableLastSync: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case clinicID = "clinic_id"
        case primaryRegions = "primary_regions"
        case recoverySignals = "recovery_signals"
        case goals
        case activityContext = "activity_context"
        case sensitivities
        case notes
        case wearableHRV = "wearable_hrv"
        case wearableStrain = "wearable_strain"
        case wearableSleepScore = "wearable_sleep_score"
        case wearableLastSync = "wearable_last_sync"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var clientProfile: ClientProfile {
        ClientProfile(
            id: id,
            userID: userID,
            clinicID: clinicID,
            primaryRegions: primaryRegions,
            recoverySignalsByRegion: recoverySignals,
            goals: goals,
            activityContext: activityContext,
            sensitivities: sensitivities,
            notes: notes,
            wearableHRV: wearableHRV,
            wearableStrain: wearableStrain,
            wearableSleepScore: wearableSleepScore,
            wearableLastSync: wearableLastSync,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct ClientProfileWriteRow: Encodable {
    let userID: UUID
    let clinicID: UUID?
    let primaryRegions: [BodyRegion]
    let recoverySignals: [String: RecoverySignalValue]
    let goals: [RecoveryGoal]
    let activityContext: String?
    let sensitivities: [String]
    let notes: String?
    let wearableHRV: Double?
    let wearableStrain: Double?
    let wearableSleepScore: Double?
    let wearableLastSync: Date?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case clinicID = "clinic_id"
        case primaryRegions = "primary_regions"
        case recoverySignals = "recovery_signals"
        case goals
        case activityContext = "activity_context"
        case sensitivities
        case notes
        case wearableHRV = "wearable_hrv"
        case wearableStrain = "wearable_strain"
        case wearableSleepScore = "wearable_sleep_score"
        case wearableLastSync = "wearable_last_sync"
    }
}

private struct AssessmentRow: Codable {
    let id: UUID
    let clientID: UUID
    let clinicID: UUID?
    let practitionerID: UUID?
    let assessmentType: AssessmentType
    let quickPoseData: QuickPoseResult?
    let romValues: [String: Double]?
    let asymmetryScores: [String: Double]?
    let movementQualityScores: [String: Double]?
    let gaitMetrics: [String: Double]?
    let heartRate: Double?
    let breathRate: Double?
    let hrvRMSSD: Double?
    let bodyZones: [BodyRegion]?
    let recoveryGoal: RecoveryGoal?
    let subjectiveBaseline: SubjectiveBaseline?
    let recoveryMap: RecoveryMap?
    let recoveryGraphDelta: [String: Double]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case clinicID = "clinic_id"
        case practitionerID = "practitioner_id"
        case assessmentType = "assessment_type"
        case quickPoseData = "quickpose_data"
        case romValues = "rom_values"
        case asymmetryScores = "asymmetry_scores"
        case movementQualityScores = "movement_quality_scores"
        case gaitMetrics = "gait_metrics"
        case heartRate = "heart_rate"
        case breathRate = "breath_rate"
        case hrvRMSSD = "hrv_rmssd"
        case bodyZones = "body_zones"
        case recoveryGoal = "recovery_goal"
        case subjectiveBaseline = "subjective_baseline"
        case recoveryMap = "recovery_map"
        case recoveryGraphDelta = "recovery_graph_delta"
        case createdAt = "created_at"
    }

    var assessment: Assessment {
        Assessment(
            id: id,
            clientID: clientID,
            clinicID: clinicID,
            practitionerID: practitionerID,
            assessmentType: assessmentType,
            quickPoseData: quickPoseData,
            romValues: romValues ?? [:],
            asymmetryScores: asymmetryScores ?? [:],
            movementQualityScores: movementQualityScores ?? [:],
            gaitMetrics: gaitMetrics ?? [:],
            heartRate: heartRate,
            breathRate: breathRate,
            hrvRMSSD: hrvRMSSD,
            bodyZones: bodyZones ?? [],
            recoveryGoal: recoveryGoal,
            subjectiveBaseline: subjectiveBaseline,
            recoveryMap: recoveryMap,
            recoveryGraphDelta: recoveryGraphDelta ?? [:],
            createdAt: createdAt
        )
    }
}

private struct AssessmentWriteRow: Encodable {
    let id: UUID
    let clientID: UUID
    let clinicID: UUID?
    let practitionerID: UUID?
    let assessmentType: AssessmentType
    let quickPoseData: QuickPoseResult?
    let romValues: [String: Double]?
    let asymmetryScores: [String: Double]?
    let movementQualityScores: [String: Double]?
    let gaitMetrics: [String: Double]?
    let heartRate: Double?
    let breathRate: Double?
    let hrvRMSSD: Double?
    let bodyZones: [BodyRegion]?
    let recoveryGoal: RecoveryGoal?
    let subjectiveBaseline: SubjectiveBaseline?
    let recoveryMap: RecoveryMap?
    let recoveryGraphDelta: [String: Double]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case clinicID = "clinic_id"
        case practitionerID = "practitioner_id"
        case assessmentType = "assessment_type"
        case quickPoseData = "quickpose_data"
        case romValues = "rom_values"
        case asymmetryScores = "asymmetry_scores"
        case movementQualityScores = "movement_quality_scores"
        case gaitMetrics = "gait_metrics"
        case heartRate = "heart_rate"
        case breathRate = "breath_rate"
        case hrvRMSSD = "hrv_rmssd"
        case bodyZones = "body_zones"
        case recoveryGoal = "recovery_goal"
        case subjectiveBaseline = "subjective_baseline"
        case recoveryMap = "recovery_map"
        case recoveryGraphDelta = "recovery_graph_delta"
        case createdAt = "created_at"
    }
}

private struct OutcomeRow: Codable {
    let id: UUID
    let sessionID: UUID
    let clientID: UUID
    let clinicID: UUID?
    let recordedBy: OutcomeActor
    let recordedByUserID: UUID?
    let stiffnessBefore: Int?
    let stiffnessAfter: Int?
    let sorenessBefore: Int?
    let sorenessAfter: Int?
    let mobilityImproved: TriStateChoice?
    let sessionEffective: TriStateChoice?
    let readinessImproved: TriStateChoice?
    let repeatIntent: RepeatIntent?
    let romAfter: [String: Double]?
    let romDelta: [String: Double]?
    let clientNotes: String?
    let practitionerNotes: String?
    let createdAt: Date

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
    }

    var outcome: Outcome {
        Outcome(
            id: id,
            sessionID: sessionID,
            clientID: clientID,
            clinicID: clinicID,
            recordedBy: recordedBy,
            recordedByUserID: recordedByUserID,
            stiffnessBefore: stiffnessBefore,
            stiffnessAfter: stiffnessAfter,
            sorenessBefore: sorenessBefore,
            sorenessAfter: sorenessAfter,
            mobilityImproved: mobilityImproved,
            sessionEffective: sessionEffective,
            readinessImproved: readinessImproved,
            repeatIntent: repeatIntent,
            romAfter: romAfter ?? [:],
            romDelta: romDelta ?? [:],
            clientNotes: clientNotes,
            practitionerNotes: practitionerNotes,
            createdAt: createdAt
        )
    }
}

private struct OutcomeWriteRow: Encodable {
    let id: UUID
    let sessionID: UUID
    let clientID: UUID
    let clinicID: UUID?
    let recordedBy: OutcomeActor
    let recordedByUserID: UUID
    let stiffnessBefore: Int?
    let stiffnessAfter: Int?
    let sorenessBefore: Int?
    let sorenessAfter: Int?
    let mobilityImproved: TriStateChoice?
    let sessionEffective: TriStateChoice?
    let readinessImproved: TriStateChoice?
    let repeatIntent: RepeatIntent?
    let romAfter: [String: Double]?
    let romDelta: [String: Double]?
    let clientNotes: String?
    let practitionerNotes: String?
    let createdAt: Date

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
    }
}

private struct OutcomeTrendRow: Codable {
    let stiffnessBefore: Int?
    let stiffnessAfter: Int?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case stiffnessBefore = "stiffness_before"
        case stiffnessAfter = "stiffness_after"
        case createdAt = "created_at"
    }
}

private struct DailyCheckinRow: Codable {
    let id: UUID
    let clientID: UUID
    let clinicID: UUID?
    let checkinType: CheckinType
    let overallFeeling: Int
    let targetRegions: [BodyRegion]
    let activitySinceLast: String?
    let recoveryScore: Double?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case clinicID = "clinic_id"
        case checkinType = "checkin_type"
        case overallFeeling = "overall_feeling"
        case targetRegions = "target_regions"
        case activitySinceLast = "activity_since_last"
        case recoveryScore = "recovery_score"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var checkin: DailyCheckin {
        DailyCheckin(
            id: id,
            clientID: clientID,
            clinicID: clinicID,
            checkinType: checkinType,
            overallFeeling: overallFeeling,
            targetRegions: targetRegions,
            activitySinceLast: activitySinceLast,
            recoveryScore: recoveryScore,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct DailyCheckinWriteRow: Encodable {
    let id: UUID
    let clientID: UUID
    let clinicID: UUID?
    let checkinType: CheckinType
    let overallFeeling: Int
    let targetRegions: [BodyRegion]
    let activitySinceLast: String?
    let recoveryScore: Double?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case clinicID = "clinic_id"
        case checkinType = "checkin_type"
        case overallFeeling = "overall_feeling"
        case targetRegions = "target_regions"
        case activitySinceLast = "activity_since_last"
        case recoveryScore = "recovery_score"
        case createdAt = "created_at"
    }
}

private struct RecoveryGraphScoreRow: Codable {
    let value: Double
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case value
        case recordedAt = "recorded_at"
    }
}

private struct SessionLookupRow: Codable {
    let id: UUID
}

private func decodeSupabaseServiceDate(_ value: String) -> Date? {
    supabaseServiceISO8601WithFractionalSeconds.date(from: value)
        ?? supabaseServiceISO8601Standard.date(from: value)
        ?? supabaseServiceCalendarDateFormatter.date(from: value)
}

private func parseSupabaseServiceErrorMessage(from data: Data) -> String? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return String(data: data, encoding: .utf8)?.nilIfEmpty
    }

    for key in ["msg", "message", "error_description", "error", "hint"] {
        if let value = object[key] as? String, !value.isEmpty {
            return value
        }
    }

    return nil
}
