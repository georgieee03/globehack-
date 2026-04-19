import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: HydraUser?
    @Published var emailAddress = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AuthServiceProtocol
    let runtimeDescription: String
    private let startupInfoMessage: String?

    init(
        service: AuthServiceProtocol? = nil,
        runtimeDescription: String = "Demo mode",
        initialInfoMessage: String? = nil
    ) {
        self.service = service ?? MockAuthService(supabaseService: MockSupabaseService.shared)
        self.runtimeDescription = runtimeDescription
        self.startupInfoMessage = initialInfoMessage
        self.infoMessage = initialInfoMessage
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var shouldShowOnboarding: Bool {
        guard let currentUser, currentUser.role == .client else {
            return false
        }

        return !UserDefaults.standard.bool(forKey: onboardingKey(for: currentUser))
    }

    func restoreSession() async {
        guard currentUser == nil else { return }
        let restoredUser = await service.restoreSession()
        if let restoredUser {
            currentUser = restoredUser
            errorMessage = nil
        } else {
            currentUser = await service.refreshSession()
            if currentUser != nil {
                errorMessage = nil
            }
        }
    }

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil

        do {
            currentUser = try await service.signInWithApple()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sendMagicLink() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil

        do {
            try await service.signInWithEmail(emailAddress)
            infoMessage = "Magic link sent. Open it on this device to finish sign-in."
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func completeMagicLinkDemo() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil

        do {
            currentUser = try await service.verifyMagicLink(nil)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func finishOnboarding() {
        guard let currentUser else { return }
        UserDefaults.standard.set(true, forKey: onboardingKey(for: currentUser))
        objectWillChange.send()
    }

    func handleOpenURL(_ url: URL) async {
        guard Self.isLikelyAuthCallback(url) else { return }

        isLoading = true
        errorMessage = nil

        do {
            currentUser = try await service.verifyMagicLink(url)
            infoMessage = "You're signed in and ready to continue."
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() async {
        await service.signOut()
        currentUser = nil
        errorMessage = nil
        infoMessage = startupInfoMessage
    }

    private static func isLikelyAuthCallback(_ url: URL) -> Bool {
        let authKeys = [
            "access_token",
            "refresh_token",
            "code",
            "token_hash",
            "type",
            "error",
            "error_code",
            "error_description",
        ]

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let fragmentItems = URLComponents(string: "hydrascan://callback?\(url.fragment ?? "")")?.queryItems ?? []
        var parameters: [String: String] = [:]

        for item in queryItems + fragmentItems {
            parameters[item.name] = item.value ?? ""
        }

        return authKeys.contains(where: { parameters[$0] != nil })
    }

    private func onboardingKey(for user: HydraUser) -> String {
        "HydraScan.didCompleteOnboarding.\(user.id.uuidString)"
    }
}
