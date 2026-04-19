import Foundation

protocol AuthServiceProtocol {
    func restoreSession() async -> HydraUser?
    func signInWithApple() async throws -> HydraUser
    func signInWithEmail(_ email: String) async throws
    func verifyMagicLink(_ url: URL?) async throws -> HydraUser
    func refreshSession() async -> HydraUser?
    func currentUser() async -> HydraUser?
    func isAuthenticated() async -> Bool
    func signOut() async
}

enum AuthServiceError: LocalizedError {
    case invalidEmail
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Enter a valid email address to receive your magic link."
        case let .unavailable(message):
            return message
        }
    }
}

actor MockAuthService: AuthServiceProtocol {
    private var cachedUser: HydraUser?
    private var pendingMagicLinkEmail: String?
    private let supabaseService: SupabaseServiceProtocol

    init(supabaseService: SupabaseServiceProtocol) {
        self.supabaseService = supabaseService
    }

    func restoreSession() async -> HydraUser? {
        cachedUser
    }

    func signInWithApple() async throws -> HydraUser {
        let user = HydraUser(
            id: UUID(),
            clinicID: UUID(),
            role: .client,
            email: "apple-client@hydrascan.app",
            fullName: "Apple Sign-In Client",
            phone: nil,
            dateOfBirth: nil,
            authProvider: "apple",
            avatarURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        cachedUser = user
        _ = try? await supabaseService.ensureClientProfile(for: user)
        return user
    }

    func signInWithEmail(_ email: String) async throws {
        guard email.contains("@"), email.contains(".") else {
            throw AuthServiceError.invalidEmail
        }

        pendingMagicLinkEmail = email
    }

    func verifyMagicLink(_ url: URL?) async throws -> HydraUser {
        let email = pendingMagicLinkEmail
            ?? url?.absoluteString
            ?? "magic-link-client@hydrascan.app"

        let user = HydraUser(
            id: UUID(),
            clinicID: UUID(),
            role: .client,
            email: email,
            fullName: "Magic Link Client",
            phone: nil,
            dateOfBirth: nil,
            authProvider: "email",
            avatarURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        cachedUser = user
        pendingMagicLinkEmail = nil
        _ = try? await supabaseService.ensureClientProfile(for: user)
        return user
    }

    func refreshSession() async -> HydraUser? {
        cachedUser
    }

    func currentUser() async -> HydraUser? {
        cachedUser
    }

    func isAuthenticated() async -> Bool {
        cachedUser != nil
    }

    func signOut() async {
        cachedUser = nil
        pendingMagicLinkEmail = nil
    }
}
