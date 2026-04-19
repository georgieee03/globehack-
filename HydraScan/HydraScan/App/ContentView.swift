import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab: AppTab = .home

    var body: some View {
        Group {
            if !authViewModel.isAuthenticated {
                LoginView(viewModel: authViewModel)
            } else if authViewModel.shouldShowOnboarding {
                OnboardingView(viewModel: authViewModel)
            } else {
                TabView(selection: $selectedTab) {
                    HomeOverviewView(user: authViewModel.currentUser)
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(AppTab.home)

                    PlaceholderWorkflowView(
                        title: "Capture",
                        subtitle: "Rapid intake, QuickPose capture, and recovery review will live here next.",
                        accentColor: .orange,
                        checklist: [
                            "Rapid intake in under 60 seconds",
                            "Seven-step guided capture flow",
                            "On-device recovery insights",
                        ]
                    )
                    .tabItem {
                        Label("Capture", systemImage: "figure.mind.and.body")
                    }
                    .tag(AppTab.capture)

                    PlaceholderWorkflowView(
                        title: "Check-In",
                        subtitle: "Daily recovery check-ins and continuity touchpoints will connect to Supabase here.",
                        accentColor: .mint,
                        checklist: [
                            "1-5 recovery feeling score",
                            "Target region update",
                            "Recent activity context",
                        ]
                    )
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
        .animation(.easeInOut(duration: 0.2), value: authViewModel.isAuthenticated)
    }
}

private struct HomeOverviewView: View {
    let user: HydraUser?

    private let recoveryScore = RecoveryScore(
        current: 82,
        deltaFromLastWeek: 6,
        updatedAt: Date(),
        trend: [
            RecoveryScoreTrendPoint(dayLabel: "Mon", value: 72),
            RecoveryScoreTrendPoint(dayLabel: "Tue", value: 74),
            RecoveryScoreTrendPoint(dayLabel: "Wed", value: 77),
            RecoveryScoreTrendPoint(dayLabel: "Thu", value: 79),
            RecoveryScoreTrendPoint(dayLabel: "Fri", value: 82),
        ]
    )

    private let gamificationState = GamificationState(
        xp: 180,
        level: 2,
        streakDays: 4,
        lastActivityDate: Date()
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HydraScan")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Welcome back, \(user?.fullName ?? "Client").")
                            .font(.title3.weight(.semibold))
                        Text("Your recovery overview keeps the assessment, session, and follow-up loop in one place.")
                            .foregroundStyle(.secondary)
                    }

                    ScoreCard(recoveryScore: recoveryScore)
                    StreakCard(gamificationState: gamificationState)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Up")
                            .font(.headline)
                        Label("Complete today's intake and movement capture", systemImage: "camera.viewfinder")
                        Label("Review recovery signals before the next session", systemImage: "waveform.path.ecg")
                        Label("Keep your streak alive with a quick daily check-in", systemImage: "flame.fill")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .padding(24)
            }
            .navigationTitle("Recovery")
        }
    }
}

private struct ScoreCard: View {
    let recoveryScore: RecoveryScore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Score")
                .font(.headline)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(recoveryScore.current)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("/100")
                    .foregroundStyle(.secondary)
            }
            Text("Updated \(recoveryScore.updatedAt.shortDateLabel)")
                .foregroundStyle(.secondary)
            Text(recoveryScore.deltaDescription)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(recoveryScore.deltaFromLastWeek >= 0 ? .green : .orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.teal.opacity(0.14))
        )
    }
}

private struct StreakCard: View {
    let gamificationState: GamificationState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Momentum")
                    .font(.headline)
                Text("\(gamificationState.streakDays)-day streak")
                    .font(.title3.weight(.semibold))
                Text("Level \(gamificationState.level) • \(gamificationState.xp) XP")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}

private struct PlaceholderWorkflowView: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    let checklist: [String]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }

                ForEach(checklist, id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(accentColor)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle(title)
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
                    Text(viewModel.currentUser?.email ?? "Signed in with demo auth")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Environment")
                        .font(.headline)
                    Text("Supabase URL: \(HydraScanConstants.supabaseURLString)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Magic link and Apple Sign-In will connect to the backend service layer in the next task.")
                        .foregroundStyle(.secondary)
                }

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

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
