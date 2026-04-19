import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recoveryScore = RecoveryScore(current: 82, deltaFromLastWeek: 6, updatedAt: Date(), trend: [])
    @Published var gamificationState = GamificationState(xp: 0, level: 1, streakDays: 0, lastActivityDate: nil)
    @Published var clientProfile = ClientProfile.empty
    @Published var assessments: [Assessment] = []
    @Published var latestOutcome: Outcome?
    @Published var errorMessage: String?
    @Published var syncStatusMessage: String?
    @Published var isLoading = false
    @Published var activeSessionBanner = "Ready for your next guided recovery session."

    let user: HydraUser

    private let service: SupabaseServiceProtocol
    private let gamificationService: GamificationServiceProtocol
    private let offlineCacheService: OfflineCacheServiceProtocol

    init(
        user: HydraUser,
        service: SupabaseServiceProtocol,
        gamificationService: GamificationServiceProtocol = GamificationService(),
        offlineCacheService: OfflineCacheServiceProtocol = OfflineCacheService.shared
    ) {
        self.user = user
        self.service = service
        self.gamificationService = gamificationService
        self.offlineCacheService = offlineCacheService
    }

    var clientName: String {
        user.fullName
    }

    var encouragementMessage: String {
        gamificationService.encouragement(for: gamificationState.streakDays)
    }

    var hasActiveSession: Bool {
        latestOutcome == nil && assessments.first != nil
    }

    var primaryRegionsSummary: String {
        let labels = clientProfile.primaryRegions.prefix(3).map(\.displayLabel)
        return labels.isEmpty ? "No recovery regions selected yet." : labels.joined(separator: ", ")
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        syncStatusMessage = nil

        do {
            let syncedCount = try await offlineCacheService.syncCachedAssessments(using: service)
            if syncedCount > 0 {
                try await offlineCacheService.clearSyncedAssessments()
                syncStatusMessage = "Synced \(syncedCount) saved assessment\(syncedCount == 1 ? "" : "s") from your last offline capture."
            } else if await offlineCacheService.hasPendingUploads() {
                syncStatusMessage = "Saved assessments are waiting to sync when your connection returns."
            }
        } catch {
            if await offlineCacheService.hasPendingUploads() {
                syncStatusMessage = "Saved assessments are waiting to sync when your connection returns."
            }
        }

        do {
            async let profile = service.fetchClientProfile(userID: user.id)
            async let score = service.fetchRecoveryScore(clientID: user.id)
            async let trend = service.fetchRecoveryTrend(clientID: user.id)
            async let allAssessments = service.fetchAssessments(clientID: user.id)
            async let outcome = service.fetchLatestOutcome(clientID: user.id)
            async let recentCheckins = service.fetchRecentCheckins(clientID: user.id, limit: 30)

            let resolvedProfile = try await profile
            let resolvedAssessments = try await allAssessments
            let resolvedOutcome = try await outcome
            let resolvedCheckins = try await recentCheckins
            let baseScore = try await score
            let resolvedTrend = try await trend

            clientProfile = resolvedProfile
            assessments = resolvedAssessments
            latestOutcome = resolvedOutcome
            recoveryScore = RecoveryScore(
                current: baseScore.current,
                deltaFromLastWeek: baseScore.deltaFromLastWeek,
                updatedAt: baseScore.updatedAt,
                trend: resolvedTrend.isEmpty ? baseScore.trend : resolvedTrend
            )
            gamificationState = gamificationService.buildState(
                assessments: resolvedAssessments,
                outcomes: resolvedOutcome.map { [$0] } ?? [],
                checkins: resolvedCheckins
            )
            activeSessionBanner = hasActiveSession
                ? "You have a recovery session in progress. Finish feedback when you are ready."
                : "Ready for your next guided recovery session."
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
