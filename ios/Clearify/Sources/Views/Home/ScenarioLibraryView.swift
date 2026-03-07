import SwiftUI

struct ScenarioLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ScenarioLibraryViewModel
    @State private var searchText = ""

    private let dependencies: Dependencies
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    init(dependencies: Dependencies, mode: ScenarioMode, roleTrack: RoleTrack) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: ScenarioLibraryViewModel(dependencies: dependencies, mode: mode, roleTrack: roleTrack))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TalkTrackBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        TalkTrackSearchField(placeholder: "Search scenarios", text: $searchText)
                        filtersCard

                        if filteredScenarios.isEmpty {
                            emptyStateCard
                        } else {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(filteredScenarios, id: \.id) { scenario in
                                    scenarioCard(scenario)
                                }
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.load()
            }
            .onChange(of: viewModel.selectedMode) { _, _ in
                Task { await viewModel.load() }
            }
            .onChange(of: viewModel.selectedRoleTrack) { _, _ in
                Task { await viewModel.load() }
            }
            .onChange(of: viewModel.showStarredOnly) { _, _ in
                Task { await viewModel.load() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(TalkTrackTheme.ink)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.92), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()
            }

            Text("Unlock the power of focused practice")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text("Pick the exact workplace moment you want to train. Use the star on any prompt to keep it on this device.")
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)
        }
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Starred prompts")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Spacer()
                Button(viewModel.showStarredOnly ? "All prompts" : "Starred only") {
                    viewModel.showStarredOnly.toggle()
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.sky)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ScenarioMode.allCases) { mode in
                        TalkTrackModePill(title: mode.title, isSelected: viewModel.selectedMode == mode) {
                            viewModel.selectedMode = mode
                        }
                    }
                }
            }

            Menu {
                ForEach(RoleTrack.allCases) { role in
                    Button(role.title) {
                        viewModel.selectedRoleTrack = role
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.selectedRoleTrack.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(TalkTrackTheme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Text("Recommended around your \(viewModel.weakestFocus.title.lowercased()) focus. Starred prompts are saved only on this device.")
                .font(.footnote)
                .foregroundStyle(TalkTrackTheme.muted)
        }
        .padding(20)
        .talkTrackCard(radius: 30)
    }

    private func scenarioCard(_ scenario: Scenario) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                TalkTrackScenarioArtwork(mode: scenario.mode)
                Button {
                    viewModel.toggleStarredPrompt(scenario)
                } label: {
                    Image(systemName: viewModel.isStarredPrompt(scenario) ? "star.fill" : "star")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(viewModel.isStarredPrompt(scenario) ? Color.yellow : TalkTrackTheme.ink)
                        .padding(10)
                        .background(Color.white.opacity(0.92), in: Circle())
                        .padding(10)
                }
                .accessibilityLabel(viewModel.isStarredPrompt(scenario) ? "Remove star" : "Star prompt")
                .buttonStyle(.plain)
            }

            Text(scenario.promptText)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
                .lineLimit(3)

            Text(scenario.coachingWhy)
                .font(.caption)
                .foregroundStyle(TalkTrackTheme.muted)
                .lineLimit(3)

            HStack(spacing: 8) {
                compactChip(scenario.recommendedDurationLabel)
                compactChip(scenario.difficulty.capitalized)
            }

            HStack(spacing: 8) {
                quickButton("Full") {
                    startSession(for: scenario, type: .full)
                }
                quickButton("Quick") {
                    startSession(for: scenario, type: .quick)
                }
            }
        }
        .padding(14)
        .talkTrackCard(radius: 28)
    }

    private func compactChip(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(TalkTrackTheme.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.74), in: Capsule())
    }

    private func quickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(title == "Full" ? Color.white : TalkTrackTheme.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(title == "Full" ? TalkTrackTheme.indigo : Color.white.opacity(0.9), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emptyStateTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .talkTrackCard(radius: 24)
    }

    private var filteredScenarios: [Scenario] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return viewModel.scenarios
        }

        let query = searchText.lowercased()
        return viewModel.scenarios.filter {
            $0.promptText.lowercased().contains(query) ||
            $0.coachingWhy.lowercased().contains(query) ||
            $0.defaultStructureHint.lowercased().contains(query)
        }
    }

    private var emptyStateTitle: String {
        if viewModel.showStarredOnly {
            return searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No starred prompts yet"
                : "No starred prompts match"
        }
        return "No scenarios match"
    }

    private var emptyStateMessage: String {
        if viewModel.showStarredOnly {
            return searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Star a prompt to keep it on this device for fast access later."
                : "Try a different search or switch back to all prompts."
        }
        return "Try a different search or update your mode and role filters."
    }

    private func startSession(for scenario: Scenario, type: SessionType) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            appState.activeSessionContext = SessionContext(mode: viewModel.selectedMode, scenario: scenario, sessionType: type)
        }
    }
}
