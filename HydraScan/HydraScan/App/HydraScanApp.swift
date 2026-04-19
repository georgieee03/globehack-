import SwiftUI

@main
struct HydraScanApp: App {
    private let services: HydraScanAppServices
    @StateObject private var authViewModel: AuthViewModel

    init() {
        let services = HydraScanAppServices.make()
        self.services = services
        _authViewModel = StateObject(
            wrappedValue: AuthViewModel(
                service: services.authService,
                runtimeDescription: services.runtimeDescription,
                initialInfoMessage: services.initialInfoMessage
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(service: services.dataService)
                .environmentObject(authViewModel)
                .task {
                    await authViewModel.restoreSession()
                }
                .onOpenURL { url in
                    Task {
                        await authViewModel.handleOpenURL(url)
                    }
                }
        }
    }
}

private struct HydraScanAppServices {
    let dataService: SupabaseServiceProtocol
    let authService: AuthServiceProtocol
    let runtimeDescription: String
    let initialInfoMessage: String?

    static func make() -> HydraScanAppServices {
        guard HydraScanConstants.usesLiveServices else {
            let mockService = MockSupabaseService.shared
            return HydraScanAppServices(
                dataService: mockService,
                authService: MockAuthService(supabaseService: mockService),
                runtimeDescription: "Demo mode (mock services)",
                initialInfoMessage: "Demo mode is active. Add SUPABASE_URL and SUPABASE_ANON_KEY to enable live Supabase auth."
            )
        }

        #if canImport(AuthenticationServices)
        do {
            let dataService = try LiveSupabaseService()
            let authService = try LiveAuthService(supabaseService: dataService)
            return HydraScanAppServices(
                dataService: dataService,
                authService: authService,
                runtimeDescription: "Live Supabase",
                initialInfoMessage: "Live Supabase auth is enabled. Apple Sign-In and magic links still need real provider credentials configured in Supabase and Apple Developer."
            )
        } catch {
            let mockService = MockSupabaseService.shared
            return HydraScanAppServices(
                dataService: mockService,
                authService: MockAuthService(supabaseService: mockService),
                runtimeDescription: "Demo mode (live auth unavailable)",
                initialInfoMessage: "Falling back to demo mode because live auth could not start: \(error.localizedDescription)"
            )
        }
        #else
        let mockService = MockSupabaseService.shared
        return HydraScanAppServices(
            dataService: mockService,
            authService: MockAuthService(supabaseService: mockService),
            runtimeDescription: "Demo mode (AuthenticationServices unavailable)",
            initialInfoMessage: "This build cannot start the live auth stack, so HydraScan is running in demo mode."
        )
        #endif
    }
}
