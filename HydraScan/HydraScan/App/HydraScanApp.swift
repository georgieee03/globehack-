import SwiftUI

@main
struct HydraScanApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .task {
                    await authViewModel.restoreSession()
                }
        }
    }
}
