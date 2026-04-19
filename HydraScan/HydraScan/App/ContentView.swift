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
                HydraBrandStage(
                    eyebrow: "HydraScan Launch",
                    title: "Loading your recovery environment.",
                    subtitle: "Assessments, clinic context, and session continuity are syncing into one polished view.",
                    showsProgress: true
                )
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
    let user: HydraUser
    let service: SupabaseServiceProtocol
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
        self.user = user
        self.service = service
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

                    if let activePlan = viewModel.activeRecoveryPlan {
                        NavigationLink {
                            RecoveryPlanView(user: user, service: service, initialPlan: activePlan)
                        } label: {
                            HydraCard(role: .ivory) {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Active Recovery Plan")
                                                .font(HydraTypography.section(28))
                                                .foregroundStyle(HydraTheme.Colors.ink)

                                            Text(activePlan.summary)
                                                .font(HydraTypography.body(15))
                                                .foregroundStyle(HydraTheme.Colors.inkSecondary)
                                        }

                                        Spacer()

                                        HydraBrandLogo(height: 20, maxWidth: 120, alignment: .trailing)
                                    }

                                    HydraMetricRow(
                                        label: "Completed This Week",
                                        value: "\(activePlan.progress.completedThisWeek)/\(activePlan.progress.assignedThisWeek)",
                                        accent: HydraTheme.Colors.ink,
                                        labelWidth: 140
                                    )

                                    HydraMetricRow(
                                        label: "Next Item",
                                        value: activePlan.nextSuggestedItem?.video.title ?? "Review your plan",
                                        accent: HydraTheme.Colors.ink,
                                        labelWidth: 140
                                    )
                                }
                            }
                        }
                        .buttonStyle(.plain)
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

                                HydraBrandLogo(height: 18, maxWidth: 110, alignment: .trailing)
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

    private var roleLabel: String {
        viewModel.sessionContext?.role.rawValue.capitalized ?? "Client"
    }

    private var clinicName: String {
        viewModel.sessionContext?.clinic?.name ?? "Clinic not assigned"
    }

    private var sessionModeLabel: String {
        switch viewModel.sessionMode {
        case .demo:
            return "Demo QA"
        case .real:
            return "Real Account"
        case nil:
            return "Signed Out"
        }
    }

    private var diagnosticsTimestamp: String {
        guard let date = viewModel.authDiagnostics.lastSuccessfulFunctionAt else {
            return "No authenticated function calls yet"
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HydraPageHeader(
                        eyebrow: "Profile & Access",
                        title: viewModel.currentUser?.fullName ?? "HydraScan Client",
                        subtitle: viewModel.currentUser?.email ?? viewModel.authUser?.email ?? "Signed in with HydraScan auth"
                    )

                    HydraCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 14) {
                                HydraBrandLogo(height: 22, maxWidth: 132)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Access Identity")
                                        .font(HydraTypography.section(26))
                                        .foregroundStyle(HydraTheme.Colors.primaryText)
                                    Text("Your app session, clinic context, and connected environment stay visible here so support and verification never feel buried.")
                                        .font(HydraTypography.body(15))
                                        .foregroundStyle(HydraTheme.Colors.secondaryText)
                                }
                            }

                            HydraMetricRow(label: "Role", value: roleLabel)
                            HydraMetricRow(label: "Session Mode", value: sessionModeLabel)
                            HydraMetricRow(label: "Clinic", value: clinicName)
                            HydraMetricRow(
                                label: "Client Profile",
                                value: viewModel.sessionContext?.clientProfileID?.uuidString.prefix(8).uppercased() ?? "Pending"
                            )
                        }
                    }

                    if viewModel.sessionMode == .demo {
                        HydraStatusBanner(
                            message: "This device is using the seeded demo QA client. Real accounts continue to use Apple Sign-In or Magic Link.",
                            tone: .warning,
                            icon: "person.crop.circle.badge.exclamationmark"
                        )
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

                    HydraCard(role: .panel) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Verification & Tooling")
                                .font(HydraTypography.section(26))
                                .foregroundStyle(HydraTheme.Colors.primaryText)

                            Text("Use the verification lab whenever you want to confirm camera tracking, overlays, and saved artifacts on a real device without leaving the branded app shell.")
                                .font(HydraTypography.body(15))
                                .foregroundStyle(HydraTheme.Colors.secondaryText)

#if canImport(QuickPoseCore) && canImport(QuickPoseSwiftUI)
                            NavigationLink {
                                QuickPoseVerificationView()
                            } label: {
                                Label("Open QuickPose Verification Lab", systemImage: "scope")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(HydraButtonStyle(kind: .secondary))
#endif
                        }
                    }

#if DEBUG
                    HydraCard(role: .panel) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Auth Diagnostics")
                                .font(HydraTypography.section(26))
                                .foregroundStyle(HydraTheme.Colors.primaryText)

                            Text("Use this debug snapshot to verify that device auth state and authenticated Edge Function access are actually in sync.")
                                .font(HydraTypography.body(15))
                                .foregroundStyle(HydraTheme.Colors.secondaryText)

                            HydraMetricRow(label: "Auth User", value: viewModel.authDiagnostics.authUserID?.uuidString.prefix(8).uppercased() ?? "None")
                            HydraMetricRow(label: "Email", value: viewModel.authDiagnostics.email ?? "None")
                            HydraMetricRow(
                                label: "Providers",
                                value: viewModel.authDiagnostics.providers.isEmpty
                                    ? "None"
                                    : viewModel.authDiagnostics.providers.joined(separator: ", ")
                            )
                            HydraMetricRow(label: "Session Exists", value: viewModel.authDiagnostics.sessionExists ? "Yes" : "No")
                            HydraMetricRow(label: "Access Token", value: viewModel.authDiagnostics.accessTokenPresent ? "Present" : "Missing")
                            HydraMetricRow(
                                label: "Last Auth Function",
                                value: viewModel.authDiagnostics.lastSuccessfulFunctionName ?? "Not yet"
                            )
                            HydraMetricRow(label: "Last Success", value: diagnosticsTimestamp)

                            Button("Refresh Diagnostics") {
                                Task {
                                    await viewModel.refreshDiagnostics()
                                }
                            }
                            .buttonStyle(HydraButtonStyle(kind: .secondary))
                        }
                    }
#endif

                    HydraCard(role: .ivory) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Account Controls")
                                .font(HydraTypography.section(26))
                                .foregroundStyle(HydraTheme.Colors.ink)

                            Text("Signing out clears the current client session from this device and returns the app to the HydraScan auth shell.")
                                .font(HydraTypography.body(15))
                                .foregroundStyle(HydraTheme.Colors.inkSecondary)

                            Button("Sign Out") {
                                Task {
                                    await viewModel.signOut()
                                }
                            }
                            .buttonStyle(HydraButtonStyle(kind: .destructive))
                        }
                    }
                }
                .padding(HydraTheme.Spacing.page)
            }
            .toolbar(.hidden, for: .navigationBar)
            .hydraShell()
            .task {
                await viewModel.refreshDiagnostics()
            }
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
