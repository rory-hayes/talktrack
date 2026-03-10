import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: HomeViewModel
    @State private var showLibrary = false
    @State private var searchText = ""

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: HomeViewModel(dependencies: dependencies))
    }

    var body: some View {
        ZStack {
            TalkTrackBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    topBar
                    greetingBlock
                    modeStrip
                    featuredPromptCard
                    scenarioGallery
                    recentMomentumSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .task {
            viewModel.selectedMode = appState.selectedMode
            viewModel.roleTrack = appState.selectedRoleTrack
            await viewModel.load()
        }
        .sheet(isPresented: $showLibrary) {
            ScenarioLibraryView(
                dependencies: dependencies,
                mode: viewModel.selectedMode,
                roleTrack: viewModel.roleTrack
            )
            .environmentObject(appState)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()

            Button {
                showLibrary = true
            } label: {
                Circle()
                    .fill(LinearGradient(colors: [TalkTrackTheme.lavender, TalkTrackTheme.sky], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(greetingInitials)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var greetingBlock: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hello,")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text(greetingName)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text("Your next best prompt is ready below. Switch modes only if you want a different kind of practice.")
                    .font(.subheadline)
                    .foregroundStyle(TalkTrackTheme.muted)
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 12) {
                TalkTrackStatChip(title: "Streak", value: "\(viewModel.streak)d")
                TalkTrackStatChip(title: "Avg", value: "\(Int(viewModel.avgScore7d.rounded()))")
            }
        }
    }

    private var modeStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ScenarioMode.allCases) { mode in
                    TalkTrackModePill(title: mode.title, isSelected: viewModel.selectedMode == mode) {
                        viewModel.selectedMode = mode
                        appState.selectedMode = mode
                        Task { await viewModel.load() }
                    }
                }
            }
            .padding(10)
            .talkTrackCard(radius: 24)
        }
    }

    private var featuredPromptCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            TalkTrackSectionHeader(title: "Start here", actionTitle: "Browse prompts") {
                showLibrary = true
            }

            if viewModel.isLoading && viewModel.recommendedScenario == nil {
                recommendationLoadingCard
            } else if let scenario = viewModel.recommendedScenario {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Best next prompt for \(viewModel.selectedMode.title.lowercased()) practice.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TalkTrackTheme.muted)

                    Text("Start a full session for three coached reps, or take one quick drill if you only have a minute.")
                        .font(.footnote)
                        .foregroundStyle(TalkTrackTheme.muted)
                }

                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.83, green: 0.67, blue: 0.98), Color(red: 0.39, green: 0.53, blue: 0.98)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 320)

                    TalkTrackScenarioArtwork(mode: scenario.mode)
                        .padding(.horizontal, 20)
                        .padding(.top, 26)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why this prompt today")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.75))
                        Text(scenario.promptText)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(scenario.coachingWhy)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(24)
                }

                HStack(spacing: 12) {
                    homeActionButton(
                        title: "Start 3-rep practice",
                        subtitle: "Full session • deeper coaching",
                        isPrimary: true
                    ) {
                        appState.activeSessionContext = SessionContext(mode: viewModel.selectedMode, scenario: scenario, sessionType: .full)
                    }
                    .accessibilityIdentifier("home.startFullSession")

                    homeActionButton(
                        title: "Take 1 quick drill",
                        subtitle: "One rep • keep momentum",
                        isPrimary: false
                    ) {
                        appState.activeSessionContext = SessionContext(mode: viewModel.selectedMode, scenario: scenario, sessionType: .quick)
                    }
                    .accessibilityIdentifier("home.startQuickDrill")
                }
            } else {
                recommendationUnavailableCard
            }
        }
    }

    private var scenarioGallery: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Need a different prompt?")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text("Search within this mode, or open the full library if you want a different scenario.")
                    .font(.footnote)
                    .foregroundStyle(TalkTrackTheme.muted)
                TalkTrackSearchField(placeholder: "Search this mode", text: $searchText)
            }

            TalkTrackSectionHeader(title: hasActiveSearch ? "Search results" : "Or choose a different prompt", actionTitle: "Open library") {
                showLibrary = true
            }

            if displayedScenarios.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No prompts match that search")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                    Text("Open the library to browse every prompt or clear the search to return to the recommended list.")
                        .font(.footnote)
                        .foregroundStyle(TalkTrackTheme.muted)

                    Button("Open prompt library") {
                        showLibrary = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TalkTrackTheme.indigo)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .talkTrackCard(radius: 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(displayedScenarios.prefix(8), id: \.id) { scenario in
                            Button {
                                appState.activeSessionContext = SessionContext(
                                    mode: viewModel.selectedMode,
                                    scenario: scenario,
                                    sessionType: .full
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    TalkTrackScenarioArtwork(mode: scenario.mode)
                                    Text(scenario.promptText)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(TalkTrackTheme.ink)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                    Text("3 reps • \(scenario.recommendedDurationLabel)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(TalkTrackTheme.muted)
                                }
                                .padding(14)
                                .frame(width: 250, alignment: .leading)
                                .talkTrackCard(radius: 28)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var recentMomentumSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TalkTrackSectionHeader(title: "Recent momentum", actionTitle: "Progress") {
                appState.selectedTab = .progress
            }

            VStack(spacing: 12) {
                if viewModel.recentSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No sessions yet")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(TalkTrackTheme.ink)
                        Text("Complete your first rep and this becomes your weekly coaching loop.")
                            .font(.subheadline)
                            .foregroundStyle(TalkTrackTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .talkTrackCard(radius: 24)
                } else {
                    ForEach(viewModel.recentSessions.prefix(3)) { session in
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(LinearGradient(colors: [TalkTrackTheme.blush, TalkTrackTheme.mist], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: iconName(for: session.mode))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(TalkTrackTheme.indigo)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.scenarioPrompt)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(TalkTrackTheme.ink)
                                    .lineLimit(2)
                                Text(session.topImprovement)
                                    .font(.footnote)
                                    .foregroundStyle(TalkTrackTheme.muted)
                                    .lineLimit(2)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(session.finalScore)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(TalkTrackTheme.ink)
                                Text(session.improvementDelta >= 0 ? "+\(session.improvementDelta)" : "\(session.improvementDelta)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(TalkTrackTheme.sky)
                            }
                        }
                        .padding(16)
                        .talkTrackCard(radius: 24)
                    }
                }
            }
        }
    }

    private var recommendationLoadingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Finding your best next prompt")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            Text("We’re loading the most relevant prompt for your current mode, role, and recent coaching data.")
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)

            ProgressView()
                .tint(TalkTrackTheme.indigo)
                .scaleEffect(1.1, anchor: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .talkTrackCard(radius: 28)
    }

    private var recommendationUnavailableCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your next prompt isn’t ready yet")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            Text(viewModel.errorMessage ?? "Open the prompt library to choose a scenario yourself, or try loading again.")
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)

            HStack(spacing: 12) {
                Button("Open prompt library") {
                    showLibrary = true
                }
                .buttonStyle(.borderedProminent)
                .tint(TalkTrackTheme.indigo)

                Button("Try again") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.bordered)
                .tint(TalkTrackTheme.indigo)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .talkTrackCard(radius: 28)
    }

    private func homeActionButton(title: String, subtitle: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
            }
            .foregroundStyle(isPrimary ? Color.white : TalkTrackTheme.indigo)
            .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isPrimary ? TalkTrackTheme.indigo : Color.white.opacity(0.9), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var displayedScenarios: [Scenario] {
        let baseScenarios: [Scenario]
        if hasActiveSearch {
            baseScenarios = viewModel.scenarios
        } else {
            baseScenarios = viewModel.scenarios.filter { $0.id != viewModel.recommendedScenario?.id }
        }

        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return baseScenarios
        }

        let query = searchText.lowercased()
        return baseScenarios.filter {
            $0.promptText.lowercased().contains(query) ||
            $0.coachingWhy.lowercased().contains(query) ||
            $0.defaultStructureHint.lowercased().contains(query)
        }
    }

    private var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var greetingName: String {
        if !appState.preferredFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return appState.preferredFirstName
        }
        if !viewModel.preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.preferredName
        }
        if let displayName = dependencies.authService.user?.displayName, !displayName.isEmpty {
            return displayName
        }
        if let email = dependencies.authService.user?.email, let prefix = email.split(separator: "@").first {
            return String(prefix).capitalized
        }
        return viewModel.roleTrack.title
    }

    private var greetingInitials: String {
        greetingName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
    }

    private func iconName(for mode: ScenarioMode) -> String {
        switch mode {
        case .interview:
            return "briefcase.fill"
        case .workplace:
            return "waveform.path.ecg"
        case .customer:
            return "person.2.fill"
        }
    }
}
