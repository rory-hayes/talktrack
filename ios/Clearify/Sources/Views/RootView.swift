import SwiftUI

struct RootView: View {
    @EnvironmentObject private var dependencies: Dependencies
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isBootstrapping {
                bootstrappingView
            } else if !appState.isOnboardingComplete {
                OnboardingView(dependencies: dependencies)
            } else {
                mainShell
            }
        }
        .task(id: UITestBootstrap.hydrationTaskID(currentUserID: dependencies.authService.user?.uid)) {
            appState.isBootstrapping = true
            await UITestBootstrap.prepareAuthenticatedDashboardStateIfNeeded(dependencies: dependencies)
            await appState.hydrate(dependencies: dependencies)
        }
        .sheet(item: $appState.activeSessionContext) { context in
            PracticeSessionView(context: context, dependencies: dependencies)
        }
    }

    private var bootstrappingView: some View {
        ZStack {
            TalkTrackBackground()
            VStack(spacing: 24) {
                TalkTrackHeroArtwork(height: 220)
                    .padding(.horizontal, 44)

                VStack(spacing: 10) {
                    Text("Loading your coaching profile")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                    Text("Setting up your prompts, progress, and practice history.")
                        .font(.subheadline)
                        .foregroundStyle(TalkTrackTheme.muted)
                }
                ProgressView()
                    .tint(TalkTrackTheme.indigo)
                    .scaleEffect(1.2)
            }
            .padding(28)
        }
    }

    private var mainShell: some View {
        ZStack {
            currentTabView
        }
        .safeAreaInset(edge: .bottom) {
            TalkTrackBottomBar(selectedTab: $appState.selectedTab)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(Color.clear)
        }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch appState.selectedTab {
        case .home:
            HomeView(dependencies: dependencies)
        case .progress:
            ProgressViewScreen(dependencies: dependencies)
        case .profile:
            ProfileView()
        }
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var dependencies: Dependencies
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    accountCard
                    preferenceCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(TalkTrackBackground())
            .sheet(isPresented: $showSettings) {
                ProfileSettingsView(dependencies: dependencies)
                    .environmentObject(appState)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text("Review your account details and coaching setup.")
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Circle()
                    .fill(LinearGradient(colors: [TalkTrackTheme.lavender, TalkTrackTheme.sky], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                    Text(accountSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(TalkTrackTheme.muted)
                }
            }

            if dependencies.authService.user != nil {
                Button("Edit Profile") {
                    showSettings = true
                }
                .buttonStyle(.borderedProminent)
                .tint(TalkTrackTheme.indigo)

                Button("Sign Out") {
                    try? dependencies.authService.signOut()
                    appState.resetForSignOut(clearCache: true)
                }
                .buttonStyle(.bordered)
                .tint(TalkTrackTheme.indigo)
            }
        }
        .padding(22)
        .talkTrackCard()
    }

    private var preferenceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Practice setup")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            HStack(spacing: 12) {
                TalkTrackStatChip(title: "Goal", value: appState.selectedMode.title)
                TalkTrackStatChip(title: "Track", value: appState.selectedRoleTrack.title)
            }

            HStack(spacing: 12) {
                TalkTrackStatChip(title: "Level", value: appState.experienceLevel.title)
                TalkTrackStatChip(title: "Focus", value: appState.selfReportedFocus.title)
            }

            Text("Update your coaching setup here whenever your role, goals, or communication focus changes.")
                .font(.footnote)
                .foregroundStyle(TalkTrackTheme.muted)
        }
        .padding(22)
        .talkTrackCard()
    }

    private var displayName: String {
        if !appState.preferredFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return appState.preferredFirstName
        }
        if let user = dependencies.authService.user {
            return user.displayName ?? user.email ?? "Clearify User"
        }
        return "Clearify User"
    }

    private var accountSubtitle: String {
        dependencies.authService.user?.email ?? "Your coaching profile is connected to this account."
    }

    private var initials: String {
        displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
    }
}
