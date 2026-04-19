import Foundation

#if canImport(InsForge)
import InsForge
#endif

struct AuthStateSnapshot: Equatable {
    var authUser: HydraAuthUser?
    var sessionContext: HydraSessionContext?

    static let empty = AuthStateSnapshot(authUser: nil, sessionContext: nil)
}

@MainActor
protocol AuthServiceProtocol {
    func restoreSession() async throws -> AuthStateSnapshot
    func signInWithApple(idToken: String, fullName: String?) async throws -> AuthStateSnapshot
    func signInWithPassword(email: String, password: String) async throws -> AuthStateSnapshot
    func signInWithEmail(_ email: String) async throws
    func verifyMagicLink(_ url: URL) async throws -> AuthStateSnapshot
    func refreshSession() async throws -> AuthStateSnapshot
    func currentAuthState() async throws -> AuthStateSnapshot
    func signOut() async
}

enum AuthServiceError: LocalizedError {
    case invalidEmail
    case missingIdentityToken
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Enter a valid email address to receive your magic link."
        case .missingIdentityToken:
            return "Apple Sign-In did not return an identity token for this request."
        case let .unavailable(message):
            return message
        }
    }
}

@MainActor
final class MockAuthService: AuthServiceProtocol {
    private let insforgeService: InsforgeServiceProtocol
    private let liveService: LiveAuthService?
    private var cachedAuthUser: HydraAuthUser?
    private var cachedContext: HydraSessionContext?
    private var pendingMagicLinkEmail: String?

    init(
        insforgeService: InsforgeServiceProtocol,
        useLiveServices: Bool? = nil
    ) {
        self.insforgeService = insforgeService
        if useLiveServices ?? HydraRuntime.shouldUseLiveServices {
            liveService = try? LiveAuthService(insforgeService: insforgeService)
        } else {
            liveService = nil
        }
    }

    func restoreSession() async throws -> AuthStateSnapshot {
        if let liveService {
            return try await liveService.restoreSession()
        }

        return AuthStateSnapshot(authUser: cachedAuthUser, sessionContext: cachedContext)
    }

    func signInWithApple(idToken: String, fullName: String?) async throws -> AuthStateSnapshot {
        if let liveService {
            return try await liveService.signInWithApple(idToken: idToken, fullName: fullName)
        }

        let appUser = HydraUser(
            id: UUID(),
            clinicID: nil,
            role: .client,
            email: "apple-client@hydrascan.app",
            fullName: fullName ?? "HydraScan Client",
            phone: nil,
            dateOfBirth: nil,
            authProvider: "apple",
            avatarURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let authUser = HydraAuthUser(
            id: appUser.id,
            email: appUser.email,
            phone: nil,
            providers: ["apple"],
            lastSignInAt: Date(),
            createdAt: appUser.createdAt,
            updatedAt: appUser.updatedAt
        )
        cachedAuthUser = authUser
        cachedContext = nil
        return AuthStateSnapshot(authUser: authUser, sessionContext: nil)
    }

    func signInWithPassword(email: String, password: String) async throws -> AuthStateSnapshot {
        if let liveService {
            return try await liveService.signInWithPassword(email: email, password: password)
        }

        guard email.contains("@"), email.contains("."), !password.isEmpty else {
            throw AuthServiceError.invalidEmail
        }

        let authUser = HydraAuthUser(
            id: UUID(),
            email: email,
            phone: nil,
            providers: ["email"],
            lastSignInAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        cachedAuthUser = authUser
        cachedContext = nil
        return AuthStateSnapshot(authUser: authUser, sessionContext: nil)
    }

    func signInWithEmail(_ email: String) async throws {
        if let liveService {
            try await liveService.signInWithEmail(email)
            return
        }

        guard email.contains("@"), email.contains(".") else {
            throw AuthServiceError.invalidEmail
        }

        pendingMagicLinkEmail = email
    }

    func verifyMagicLink(_ url: URL) async throws -> AuthStateSnapshot {
        if let liveService {
            return try await liveService.verifyMagicLink(url)
        }

        let email = pendingMagicLinkEmail ?? url.absoluteString
        let authUser = HydraAuthUser(
            id: UUID(),
            email: email,
            phone: nil,
            providers: ["email"],
            lastSignInAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        cachedAuthUser = authUser
        cachedContext = nil
        pendingMagicLinkEmail = nil
        return AuthStateSnapshot(authUser: authUser, sessionContext: nil)
    }

    func refreshSession() async throws -> AuthStateSnapshot {
        if let liveService {
            return try await liveService.refreshSession()
        }

        return AuthStateSnapshot(authUser: cachedAuthUser, sessionContext: cachedContext)
    }

    func currentAuthState() async throws -> AuthStateSnapshot {
        if let liveService {
            return try await liveService.currentAuthState()
        }

        return AuthStateSnapshot(authUser: cachedAuthUser, sessionContext: cachedContext)
    }

    func signOut() async {
        if let liveService {
            await liveService.signOut()
            return
        }

        cachedAuthUser = nil
        cachedContext = nil
        pendingMagicLinkEmail = nil
        await insforgeService.resetSessionContext()
    }
}

#if canImport(InsForge)
@MainActor
final class LiveAuthService: AuthServiceProtocol {
    private let insforgeService: InsforgeServiceProtocol
    private let core: HydraInsforgeCore

    init(insforgeService: InsforgeServiceProtocol) throws {
        guard let core = HydraInsforgeCore.shared else {
            throw AuthServiceError.unavailable("InsForge is unavailable in this build.")
        }

        self.insforgeService = insforgeService
        self.core = core
    }

    func restoreSession() async throws -> AuthStateSnapshot {
        try await loadCurrentSnapshot(allowProvisioningRetry: false)
    }

    func signInWithApple(idToken: String, fullName: String?) async throws -> AuthStateSnapshot {
        let session = try await core.client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken
            )
        )

        if let fullName, !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = try? await core.client.auth.update(
                user: UserAttributes(data: ["full_name": .string(fullName)])
            )
        }

        return try await buildSnapshot(from: session.user, allowProvisioningRetry: true)
    }

    func signInWithPassword(email: String, password: String) async throws -> AuthStateSnapshot {
        let session = try await core.client.auth.signIn(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )

        return try await buildSnapshot(from: session.user, allowProvisioningRetry: true)
    }

    func signInWithEmail(_ email: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            throw AuthServiceError.invalidEmail
        }

        guard let callbackURL = HydraRuntime.authCallbackURL else {
            throw InsforgeServiceError.missingCallbackConfiguration
        }

        try await core.client.auth.signInWithOTP(
            email: trimmedEmail,
            redirectTo: callbackURL
        )
    }

    func verifyMagicLink(_ url: URL) async throws -> AuthStateSnapshot {
        let session = try await core.client.auth.session(from: url)
        return try await buildSnapshot(from: session.user, allowProvisioningRetry: true)
    }

    func refreshSession() async throws -> AuthStateSnapshot {
        try await loadCurrentSnapshot(allowProvisioningRetry: true)
    }

    func currentAuthState() async throws -> AuthStateSnapshot {
        try await loadCurrentSnapshot(allowProvisioningRetry: false)
    }

    func signOut() async {
        try? await core.client.auth.signOut()
        await insforgeService.resetSessionContext()
    }

    private func loadCurrentSnapshot(allowProvisioningRetry: Bool) async throws -> AuthStateSnapshot {
        if let currentSession = core.client.auth.currentSession {
            return try await buildSnapshot(from: currentSession.user, allowProvisioningRetry: allowProvisioningRetry)
        }

        do {
            let session = try await core.client.auth.session
            return try await buildSnapshot(from: session.user, allowProvisioningRetry: allowProvisioningRetry)
        } catch {
            await insforgeService.resetSessionContext()
            return .empty
        }
    }

    private func buildSnapshot(from authUser: User, allowProvisioningRetry: Bool) async throws -> AuthStateSnapshot {
        let fallbackAuthUser = mapAuthUser(authUser)

        do {
            let context = try await core.loadSessionContext(from: authUser, allowProvisioningRetry: allowProvisioningRetry)
            return AuthStateSnapshot(authUser: context.authUser, sessionContext: context)
        } catch InsforgeServiceError.incompleteOnboarding {
            await insforgeService.resetSessionContext()
            return AuthStateSnapshot(authUser: fallbackAuthUser, sessionContext: nil)
        } catch {
            throw error
        }
    }

    private func mapAuthUser(_ authUser: User) -> HydraAuthUser {
        let providers = Set(authUser.identities?.map(\.provider) ?? [])

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
#endif
