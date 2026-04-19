import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recoveryScore: RecoveryScore?
    @Published var gamificationState = GamificationState(xp: 0, level: 1, streakDays: 0, lastActivityDate: nil)
    @Published var clientProfile = ClientProfile.empty
    @Published var assessments: [Assessment] = []
    @Published var latestOutcome: Outcome?
    @Published var sessionAwareness = HydraSessionAwareness(activeSession: nil, latestSession: nil, updatedAt: Date())
    @Published var errorMessage: String?
    @Published var syncStatusMessage: String?
    @Published var isLoading = false
    @Published var activeSessionBanner = "Ready for your next guided recovery session."

    let user: HydraUser

    private let service: SupabaseServiceProtocol
    private let gamificationService: GamificationServiceProtocol
    private let offlineCacheService: OfflineCacheServiceProtocol
    private var sessionAwarenessTask: Task<Void, Never>?

    init(
        user: HydraUser,
        service: SupabaseServiceProtocol,
        gamificationService: GamificationServiceProtocol? = nil,
        offlineCacheService: OfflineCacheServiceProtocol? = nil
    ) {
        self.user = user
        self.service = service
        self.gamificationService = gamificationService ?? GamificationService()
        self.offlineCacheService = offlineCacheService ?? OfflineCacheService.shared
    }

    deinit {
        sessionAwarenessTask?.cancel()
    }

    var clientName: String {
        user.fullName
    }

    var encouragementMessage: String {
        gamificationService.encouragement(for: gamificationState.streakDays)
    }

    var hasActiveSession: Bool {
        sessionAwareness.activeSession != nil
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
            async let allAssessments = service.fetchAssessments(clientID: user.id)
            async let outcome = service.fetchLatestOutcome(clientID: user.id)
            async let recentCheckins = service.fetchRecentCheckins(clientID: user.id, limit: 30)
            async let awareness = service.fetchSessionAwareness(clientID: user.id)

            let resolvedProfile = try await profile
            let resolvedAssessments = try await allAssessments
            let resolvedOutcome = try await outcome
            let resolvedCheckins = try await recentCheckins
            let baseScore = try await score
            let resolvedAwareness = try await awareness

            clientProfile = resolvedProfile
            assessments = resolvedAssessments
            latestOutcome = resolvedOutcome
            sessionAwareness = resolvedAwareness
            recoveryScore = baseScore
            gamificationState = gamificationService.buildState(
                assessments: resolvedAssessments,
                outcomes: resolvedOutcome.map { [$0] } ?? [],
                checkins: resolvedCheckins
            )
            if let activeSession = resolvedAwareness.activeSession {
                activeSessionBanner = activeSession.status == .paused
                    ? "Your Hydrawav session is paused. Resume with your practitioner when ready."
                    : "You have an active Hydrawav session in progress."
            } else if let latestSession = resolvedAwareness.latestSession,
                      latestSession.status == .completed,
                      resolvedOutcome?.sessionID != latestSession.id {
                activeSessionBanner = "Your latest session is complete. Share feedback to update your Recovery Score."
            } else {
                activeSessionBanner = "Ready for your next guided recovery session."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func startSessionAwarenessStream() {
        sessionAwarenessTask?.cancel()
        sessionAwarenessTask = Task {
            do {
                for try await awareness in service.sessionAwarenessStream(clientID: user.id) {
                    guard !Task.isCancelled else { return }
                    sessionAwareness = awareness

                    if let activeSession = awareness.activeSession {
                        activeSessionBanner = activeSession.status == .paused
                            ? "Your Hydrawav session is paused. Resume with your practitioner when ready."
                            : "You have an active Hydrawav session in progress."
                    } else if let latestSession = awareness.latestSession,
                              latestSession.status == .completed,
                              latestOutcome?.sessionID != latestSession.id {
                        activeSessionBanner = "Your latest session is complete. Share feedback to update your Recovery Score."
                    } else {
                        activeSessionBanner = "Ready for your next guided recovery session."
                    }
                }
            } catch {
                // Keep the most recent loaded state if realtime drops.
            }
        }
    }

    func stopSessionAwarenessStream() {
        sessionAwarenessTask?.cancel()
        sessionAwarenessTask = nil
    }
}
