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
            ZStack {
                HydraShellBackground()
                HydraCard {
                    HStack(spacing: 14) {
                        ProgressView()
                            .tint(HydraTheme.Colors.gold)
                        Text("Loading your HydraScan recovery environment…")
                            .font(HydraTypography.body(15, weight: .medium))
                            .foregroundStyle(HydraTheme.Colors.primaryText)
                    }
                }
                .padding(HydraTheme.Spacing.page)
            }
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
        .tint(HydraTheme.Colors.gold)
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
                VStack(alignment: .leading, spacing: 22) {
                    HydraPageHeader(
                        eyebrow: "Recovery Overview",
                        title: "Welcome back, \(viewModel.clientName).",
                        subtitle: "Your assessments, sessions, and follow-up signals stay aligned in one premium recovery dashboard."
                    )

                    if viewModel.hasActiveSession {
                        HydraStatusBanner(
                            message: viewModel.activeSessionBanner,
                            tone: .warning,
                            icon: "bolt.fill"
                        )
                    }

                    if let syncStatusMessage = viewModel.syncStatusMessage {
                        HydraStatusBanner(
                            message: syncStatusMessage,
                            tone: .success,
                            icon: "arrow.triangle.2.circlepath.circle.fill"
                        )
                    }

                    if let recoveryScore = viewModel.recoveryScore {
                        HydraCard {
                            RecoveryScoreView(recoveryScore: recoveryScore)
                        }
                    } else if viewModel.isLoading {
                        HydraCard {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(HydraTheme.Colors.gold)
                                Text("Updating your latest recovery score…")
                                    .font(HydraTypography.body(15, weight: .medium))
                                    .foregroundStyle(HydraTheme.Colors.secondaryText)
                            }
                        }
                    }

                    HydraCard(role: .panel) {
                        StreakView(
                            gamificationState: viewModel.gamificationState,
                            encouragementMessage: viewModel.encouragementMessage
                        )
                    }

                    HydraCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Next Up")
                                        .font(HydraTypography.section(26))
                                        .foregroundStyle(HydraTheme.Colors.primaryText)
                                    Text("Focus regions: \(viewModel.primaryRegionsSummary)")
                                        .font(HydraTypography.body(15))
                                        .foregroundStyle(HydraTheme.Colors.secondaryText)
                                }

                                Spacer()

                                HydraBrandEmblem(size: 34)
                            }

                            Button {
                                onStartCapture()
                            } label: {
                                Label("Start today’s guided capture", systemImage: "camera.viewfinder")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(HydraButtonStyle(kind: .primary))

                            Button {
                                onOpenCheckIn()
                            } label: {
                                Label("Log a quick daily check-in", systemImage: "waveform.path.ecg")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(HydraButtonStyle(kind: .secondary))
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        HydraStatusBanner(message: errorMessage, tone: .error, icon: "exclamationmark.triangle.fill")
                    }
                }
                .padding(HydraTheme.Spacing.page)
            }
            .toolbar(.hidden, for: .navigationBar)
            .hydraShell()
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
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HydraPageHeader(
                        eyebrow: "Profile & Access",
                        title: viewModel.currentUser?.fullName ?? "HydraScan Client",
                        subtitle: viewModel.currentUser?.email ?? viewModel.authUser?.email ?? "Signed in with HydraScan auth"
                    )

                    if let clinicName = viewModel.sessionContext?.clinic?.name {
                        HydraStatusBanner(message: clinicName, tone: .neutral, icon: "cross.case.fill")
                    }

                    HydraCard(role: .ivory) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Connected Environment")
                                .font(HydraTypography.section(28))
                                .foregroundStyle(HydraTheme.Colors.ink)

                            Text("Supabase URL: \(HydraScanConstants.supabaseURLString)")
                                .font(HydraTypography.body(14, weight: .medium))
                                .foregroundStyle(HydraTheme.Colors.inkSecondary)

                            Text("Session and device controls route through Supabase Edge Functions and Realtime updates instead of direct Hydrawav API calls.")
                                .font(HydraTypography.body(15))
                                .foregroundStyle(HydraTheme.Colors.inkSecondary)
                        }
                    }

#if canImport(QuickPoseCore) && canImport(QuickPoseSwiftUI)
                    NavigationLink {
                        QuickPoseVerificationView()
                    } label: {
                        Label("Open QuickPose Verification Lab", systemImage: "scope")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(HydraButtonStyle(kind: .secondary))
#endif

                    Button("Sign Out") {
                        Task {
                            await viewModel.signOut()
                        }
                    }
                    .buttonStyle(HydraButtonStyle(kind: .primary))
                }
                .padding(HydraTheme.Spacing.page)
            }
            .toolbar(.hidden, for: .navigationBar)
            .hydraShell()
        }
    }
}

private struct UnsupportedRoleView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                HydraPageHeader(
                    eyebrow: "Unsupported Role",
                    title: "This build is focused on the client recovery experience.",
                    subtitle: viewModel.unsupportedRoleMessage
                )

                HydraCard(role: .ivory) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Client-only release")
                            .font(HydraTypography.section(28))
                            .foregroundStyle(HydraTheme.Colors.ink)
                        Text("The practitioner and admin surfaces stay out of this build so the current app can fully focus on client intake, guided capture, and recovery continuity.")
                            .font(HydraTypography.body(15))
                            .foregroundStyle(HydraTheme.Colors.inkSecondary)
                    }
                }

                Button("Sign Out") {
                    Task {
                        await viewModel.signOut()
                    }
                }
                .buttonStyle(HydraButtonStyle(kind: .primary))

                Spacer(minLength: 0)
            }
            .padding(HydraTheme.Spacing.page)
            .toolbar(.hidden, for: .navigationBar)
            .hydraShell()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
