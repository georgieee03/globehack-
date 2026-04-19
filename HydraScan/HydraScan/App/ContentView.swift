import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab: AppTab = .home
    @State private var homeRefreshToken = UUID()

    private let service: SupabaseServiceProtocol = MockSupabaseService.shared
    private let debugDestination = ProcessInfo.processInfo.arguments.contains("--quickpose-lab")

    var body: some View {
        Group {
#if DEBUG
            if debugDestination {
#if canImport(QuickPoseCore) && canImport(QuickPoseSwiftUI)
                NavigationStack {
                    QuickPoseVerificationView()
                }
#else
                Text("QuickPose Verification Lab is unavailable in this build.")
#endif
            } else {
                authenticatedContent
            }
#else
            authenticatedContent
#endif
        }
        .animation(.easeInOut(duration: 0.2), value: authViewModel.isAuthenticated)
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        if !authViewModel.isAuthenticated {
            LoginView(viewModel: authViewModel)
        } else if authViewModel.shouldShowUnsupportedRole {
            UnsupportedRoleView(viewModel: authViewModel)
        } else if authViewModel.shouldShowOnboarding {
            OnboardingView(viewModel: authViewModel)
        } else if authViewModel.isClientReady, let currentUser = authViewModel.currentUser {
            mainTabs(for: currentUser)
        } else {
            ProgressView("Loading HydraScan…")
        }
    }

    @ViewBuilder
    private func mainTabs(for user: HydraUser) -> some View {
        TabView(selection: $selectedTab) {
            HomeTabView(
                user: user,
                service: service,
                refreshToken: homeRefreshToken
            ) {
                selectedTab = .capture
            } onOpenCheckIn: {
                selectedTab = .checkIn
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            CaptureExperienceView(user: user, service: service) {
                homeRefreshToken = UUID()
                selectedTab = .home
            }
            .tabItem {
                Label("Capture", systemImage: "figure.mind.and.body")
            }
            .tag(AppTab.capture)

            CheckInView(user: user, service: service) {
                homeRefreshToken = UUID()
                selectedTab = .home
            }
            .tabItem {
                Label("Check-In", systemImage: "checklist")
            }
            .tag(AppTab.checkIn)

            ProfileView(viewModel: authViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)
        }
        .tint(.teal)
    }
}

private struct HomeTabView: View {
    @StateObject private var viewModel: HomeViewModel
    let refreshToken: UUID
    let onStartCapture: () -> Void
    let onOpenCheckIn: () -> Void

    init(
        user: HydraUser,
        service: SupabaseServiceProtocol,
        refreshToken: UUID,
        onStartCapture: @escaping () -> Void,
        onOpenCheckIn: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(user: user, service: service))
        self.refreshToken = refreshToken
        self.onStartCapture = onStartCapture
        self.onOpenCheckIn = onOpenCheckIn
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HydraScan")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Welcome back, \(viewModel.clientName).")
                            .font(.title3.weight(.semibold))
                        Text("Your recovery overview keeps the assessment, session, and follow-up loop in one place.")
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.hasActiveSession {
                        Text(viewModel.activeSessionBanner)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.orange.opacity(0.12))
                            )
                    }

                    if let syncStatusMessage = viewModel.syncStatusMessage {
                        Text(syncStatusMessage)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.teal.opacity(0.12))
                            )
                    }

                    if let recoveryScore = viewModel.recoveryScore {
                        RecoveryScoreView(recoveryScore: recoveryScore)
                    } else if viewModel.isLoading {
                        ProgressView("Loading recovery score...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    StreakView(
                        gamificationState: viewModel.gamificationState,
                        encouragementMessage: viewModel.encouragementMessage
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Up")
                            .font(.headline)
                        Text("Focus regions: \(viewModel.primaryRegionsSummary)")
                            .foregroundStyle(.secondary)

                        Button {
                            onStartCapture()
                        } label: {
                            Label("Start today's guided capture", systemImage: "camera.viewfinder")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            onOpenCheckIn()
                        } label: {
                            Label("Log a quick daily check-in", systemImage: "flame.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Recovery")
            .task(id: refreshToken) {
                await viewModel.load()
                viewModel.startSessionAwarenessStream()
            }
            .onDisappear {
                viewModel.stopSessionAwarenessStream()
            }
        }
    }
}

private struct ProfileView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.currentUser?.fullName ?? "HydraScan Client")
                        .font(.title.weight(.semibold))
                    Text(viewModel.currentUser?.email ?? viewModel.authUser?.email ?? "Signed in with HydraScan auth")
                        .foregroundStyle(.secondary)
                }

                if let clinicName = viewModel.sessionContext?.clinic?.name {
                    Label(clinicName, systemImage: "cross.case")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Environment")
                        .font(.headline)
                    Text("Supabase URL: \(HydraScanConstants.supabaseURLString)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Session and device controls should route through Supabase Edge Functions and Realtime updates, not direct Hydrawav API calls from the app.")
                        .foregroundStyle(.secondary)
                }

#if canImport(QuickPoseCore) && canImport(QuickPoseSwiftUI)
                NavigationLink("QuickPose Verification Lab") {
                    QuickPoseVerificationView()
                }
                .buttonStyle(.bordered)
#endif

                Button("Sign Out") {
                    Task {
                        await viewModel.signOut()
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Profile")
        }
    }
}

private struct UnsupportedRoleView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Client Build Only")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(viewModel.unsupportedRoleMessage)
                    .foregroundStyle(.secondary)

                Button("Sign Out") {
                    Task {
                        await viewModel.signOut()
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding(24)
            .navigationTitle("HydraScan")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
