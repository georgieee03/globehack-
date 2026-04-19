import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var authUser: HydraAuthUser?
    @Published var sessionContext: HydraSessionContext?
    @Published var emailAddress = ""
    @Published var onboardingFullName = ""
    @Published var clinicInviteCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AuthServiceProtocol
    private let insforgeService: InsforgeServiceProtocol

    init(
        service: AuthServiceProtocol? = nil,
        insforgeService: InsforgeServiceProtocol? = nil
    ) {
        let resolvedInsforgeService = insforgeService ?? MockInsforgeService.shared
        self.insforgeService = resolvedInsforgeService
        self.service = service ?? MockAuthService(insforgeService: resolvedInsforgeService)
    }

    var currentUser: HydraUser? {
        sessionContext?.appUser
    }

    var isAuthenticated: Bool {
        authUser != nil
    }

    var shouldShowOnboarding: Bool {
        isAuthenticated && sessionContext == nil
    }

    var isClientReady: Bool {
        sessionContext?.role == .client && sessionContext?.clientProfileID != nil
    }

    var shouldShowUnsupportedRole: Bool {
        guard let role = sessionContext?.role else { return false }
        return role != .client
    }

    var unsupportedRoleMessage: String {
        let roleLabel = sessionContext?.role.rawValue.capitalized ?? "This account"
        return "\(roleLabel) access exists in HydraScan, but this build is focused on the client app only."
    }

    func restoreSession() async {
        guard authUser == nil, sessionContext == nil else { return }

        await loadAuthState { [self] in
            try await self.service.restoreSession()
        }

        guard authUser == nil, sessionContext == nil else { return }
        guard let qaCredentials = HydraRuntime.qaAutologinCredentials else { return }

        infoMessage = "Signing into the seeded QA client for simulator verification."
        await loadAuthState { [self] in
            try await self.service.signInWithPassword(
                email: qaCredentials.email,
                password: qaCredentials.password
            )
        }
    }

    func signInWithApple(idToken: String, fullName: String?) async {
        await loadAuthState { [self] in
            try await self.service.signInWithApple(idToken: idToken, fullName: fullName)
        }
    }

    func sendMagicLink() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil

        do {
            try await service.signInWithEmail(emailAddress)
            infoMessage = "Magic link sent. Open it on this device to continue into HydraScan."
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func handleOpenURL(_ url: URL) async {
        await loadAuthState { [self] in
            try await self.service.verifyMagicLink(url)
        }
    }

    func completeOnboarding() async {
        let trimmedName = onboardingFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = clinicInviteCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Enter the name you want your practitioner to see."
            return
        }

        guard !trimmedCode.isEmpty else {
            errorMessage = "Enter the clinic invite code you were given."
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        do {
            let context = try await insforgeService.claimClinicInvite(
                inviteCode: trimmedCode,
                fullName: trimmedName
            )
            sessionContext = context
            authUser = context.authUser
            onboardingFullName = context.appUser.fullName
            clinicInviteCode = ""

            let refreshed = try await service.refreshSession()
            apply(snapshot: refreshed)
            infoMessage = "Clinic access is ready. Your recovery profile is now live."
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() async {
        await service.signOut()
        authUser = nil
        sessionContext = nil
        emailAddress = ""
        clinicInviteCode = ""
        onboardingFullName = ""
        errorMessage = nil
        infoMessage = nil
    }

    private func loadAuthState(
        operation: @escaping () async throws -> AuthStateSnapshot
    ) async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil

        do {
            let snapshot = try await operation()
            apply(snapshot: snapshot)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func apply(snapshot: AuthStateSnapshot) {
        authUser = snapshot.authUser
        sessionContext = snapshot.sessionContext

        if onboardingFullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onboardingFullName = snapshot.sessionContext?.appUser.fullName
                ?? snapshot.authUser?.email?.components(separatedBy: "@").first?.replacingOccurrences(of: ".", with: " ").capitalized
                ?? ""
        }
    }
}
