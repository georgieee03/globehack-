import Foundation

protocol AuthServiceProtocol {
    func restoreSession() async -> HydraUser?
    func signInWithApple() async throws -> HydraUser
    func sendMagicLink(to email: String) async throws
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
        return user
    }

    func sendMagicLink(to email: String) async throws {
        guard email.contains("@"), email.contains(".") else {
            throw AuthServiceError.invalidEmail
        }
    }

    func signOut() async {
        cachedUser = nil
    }
}
