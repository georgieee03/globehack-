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

    init(service: AuthServiceProtocol = MockAuthService()) {
        self.service = service
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var shouldShowOnboarding: Bool {
        isAuthenticated && !UserDefaults.standard.bool(forKey: onboardingKey)
    }

    func restoreSession() async {
        guard currentUser == nil else { return }
        currentUser = await service.restoreSession()
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
            try await service.sendMagicLink(to: emailAddress)
            infoMessage = "Magic link sent. Check your inbox to continue."
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
