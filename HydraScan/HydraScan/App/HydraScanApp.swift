import SwiftUI

@main
struct HydraScanApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        HydraAppearance.install()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .preferredColorScheme(.dark)
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
