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
    private let onboardingKey = "HydraScan.didCompleteOnboarding"

    init(service: AuthServiceProtocol? = nil) {
        self.service = service ?? MockAuthService(supabaseService: MockSupabaseService.shared)
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var shouldShowOnboarding: Bool {
        isAuthenticated && !UserDefaults.standard.bool(forKey: onboardingKey)
    }

    func restoreSession() async {
        guard currentUser == nil else { return }
        let restoredUser = await service.restoreSession()
        if let restoredUser {
            currentUser = restoredUser
        } else {
            currentUser = await service.refreshSession()
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
            infoMessage = "Magic link sent. Check your inbox to continue."
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
        UserDefaults.standard.set(true, forKey: onboardingKey)
        objectWillChange.send()
    }

    func signOut() async {
        await service.signOut()
        currentUser = nil
        errorMessage = nil
        infoMessage = nil
    }
}
