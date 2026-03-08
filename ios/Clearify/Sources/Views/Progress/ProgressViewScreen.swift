import SwiftUI

struct ProgressViewScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ProgressViewModel
    @ObservedObject private var audioPlayer: AudioPlaybackService

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: ProgressViewModel(dependencies: dependencies))
        _audioPlayer = ObservedObject(wrappedValue: dependencies.audioPlayer)
    }

    var body: some View {
        ZStack {
            TalkTrackBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summaryCard
                    practiceNextCard
                    focusCard
                    savedAnswersSection
                    historySection

                    if let error = viewModel.errorMessage {
                        infoCard(title: viewModel.progressErrorTitle, message: error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .task {
            await viewModel.load(
                selectedMode: appState.selectedMode,
                selectedRoleTrack: appState.selectedRoleTrack,
                experienceLevel: appState.experienceLevel,
                defaultFocus: appState.selfReportedFocus
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your progress")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text("See whether your answers are improving, what keeps dragging them down, and what to practice next.")
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This week")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                    Text(viewModel.hasPracticeData ? "\(viewModel.weeklyAverage)" : "—")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Streak")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TalkTrackTheme.muted)
                    Text("\(viewModel.streak) days")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                }
            }

            if viewModel.snapshots.count >= 2 {
                SparklineChart(
                    values: Array(viewModel.snapshots.prefix(7).map(\.avgScore).reversed()),
                    lineColor: TalkTrackTheme.indigo
                )
                .frame(height: 70)
            } else {
                infoCard(
                    title: viewModel.weeklyScoreHeadline,
                    message: viewModel.weeklySummaryDetail,
                    compact: true
                )
            }

            if viewModel.snapshots.count >= 2 {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.weeklyScoreHeadline)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                    Text(viewModel.weeklySummaryDetail)
                        .font(.subheadline)
                        .foregroundStyle(TalkTrackTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(viewModel.weeklySummary)
                .font(.footnote)
                .foregroundStyle(TalkTrackTheme.muted)
        }
        .padding(22)
        .talkTrackCard(radius: 30)
    }

    private var practiceNextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TalkTrackSectionHeader(title: "Practice next")

            Text(viewModel.recommendedPracticeTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            Text(viewModel.recommendedPracticeDetail)
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            actionButton(title: viewModel.recommendedPracticeCTA) {
                guard let scenario = viewModel.recommendedScenario else { return }
                appState.activeSessionContext = SessionContext(
                    mode: scenario.mode,
                    scenario: scenario,
                    sessionType: .full
                )
            }
            .disabled(!viewModel.canRecommendPractice)
            .opacity(viewModel.canRecommendPractice ? 1 : 0.6)
        }
        .padding(22)
        .talkTrackCard(radius: 30)
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.focusCardTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text(viewModel.focusHeadline)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text(viewModel.focusDetail)
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)

            HStack(spacing: 12) {
                detailCard(title: viewModel.recurringIssueLabel, body: viewModel.topRecurringIssue)
                detailCard(title: viewModel.recentWinLabel, body: viewModel.recentWin)
            }
        }
        .padding(22)
        .talkTrackCard(radius: 30)
    }

    private var savedAnswersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TalkTrackSectionHeader(title: "Saved answers on this device")

            if viewModel.savedSessions.isEmpty {
                emptyCard(
                    title: "No saved answers yet",
                    message: "Save your strongest answer after a session to keep a polished version on this device."
                )
            }

            ForEach(viewModel.savedSessions) { session in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.scenarioPrompt)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(TalkTrackTheme.ink)
                            Text("Saved on this device from \(session.mode.title.lowercased()) practice")
                                .font(.footnote)
                                .foregroundStyle(TalkTrackTheme.muted)
                        }
                        Spacer()
                        Text("\(session.finalScore)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(TalkTrackTheme.ink)
                    }

                    if let finalRep = session.finalRep {
                        transcriptBlock(title: "Best answer", rep: finalRep)
                    }

                    Button("Practice this again") {
                        appState.activeSessionContext = SessionContext(
                            mode: session.mode,
                            scenario: Scenario(
                                id: session.scenarioId,
                                mode: session.mode,
                                promptText: session.scenarioPrompt,
                                tags: [],
                                difficulty: "medium",
                                active: true
                            ),
                            sessionType: .full
                        )
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TalkTrackTheme.indigo, in: Capsule())
                    .buttonStyle(.plain)
                }
                .padding(18)
                .talkTrackCard(radius: 26)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TalkTrackSectionHeader(title: viewModel.historySectionTitle)

            if viewModel.recentSessions.isEmpty {
                emptyCard(
                    title: "No recent sessions yet",
                    message: "Complete one practice session to see score movement, before-versus-after comparisons, and your next coaching pattern."
                )
            }

            ForEach(viewModel.recentSessions) { session in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        if let firstRep = session.firstRep {
                            transcriptBlock(title: "First try", rep: firstRep)
                        }
                        if let finalRep = session.finalRep, finalRep.id != session.firstRep?.id {
                            transcriptBlock(title: "Latest try", rep: finalRep)
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(session.scenarioPrompt)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(TalkTrackTheme.ink)
                            Spacer()
                            Text("\(session.finalScore)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(TalkTrackTheme.ink)
                        }
                        Text(viewModel.sessionMeta(for: session))
                            .font(.footnote)
                            .foregroundStyle(TalkTrackTheme.muted)
                        Text(viewModel.sessionSummary(for: session))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TalkTrackTheme.ink)
                        Text(session.topImprovement)
                            .font(.footnote)
                            .foregroundStyle(TalkTrackTheme.muted)
                    }
                }
                .padding(18)
                .talkTrackCard(radius: 26)
            }
        }
    }

    private func transcriptBlock(title: String, rep: SpeakingRep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Spacer()
                if let path = rep.localAudioPath {
                    Button(audioPlayer.currentPath == path && audioPlayer.isPlaying ? "Stop" : "Play") {
                        dependencies.audioPlayer.togglePlayback(
                            url: dependencies.localPracticeStore.absoluteURL(for: path),
                            path: path
                        )
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(TalkTrackTheme.sky)
                }
                Text("Score \(rep.score)")
                    .font(.footnote)
                    .foregroundStyle(TalkTrackTheme.muted)
            }

            Text(rep.shortTranscript)
                .font(.callout)
                .foregroundStyle(TalkTrackTheme.ink)

            Text(rep.feedback.primaryImprovement)
                .font(.footnote)
                .foregroundStyle(TalkTrackTheme.muted)
        }
        .padding(16)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func detailCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text(body)
                .font(.footnote)
                .foregroundStyle(TalkTrackTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func emptyCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .talkTrackCard(radius: 24)
    }

    private func infoCard(title: String, message: String, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: compact ? 16 : 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 16 : 18)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(TalkTrackTheme.indigo, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
