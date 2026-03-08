import SwiftUI

struct PracticeSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: PracticeSessionViewModel
    @State private var relatedScenario: Scenario?

    private let context: SessionContext
    private let dependencies: Dependencies

    init(context: SessionContext, dependencies: Dependencies) {
        self.context = context
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: PracticeSessionViewModel(dependencies: dependencies, context: context))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        topBar
                        promptCard
                        if viewModel.sessionId != nil || viewModel.isBusy {
                            recorderStage
                        } else {
                            unavailableStage
                        }

                        if let feedback = viewModel.latestFeedback {
                            FeedbackCardView(response: feedback)
                        }

                        if let pair = viewModel.beforeAfterPair {
                            beforeAfterCard(pair)
                        }

                        if !viewModel.reps.isEmpty {
                            repTimeline
                        }

                        if let completion = viewModel.completion {
                            completionCard(completion)
                        }

                        if let error = viewModel.errorMessage, viewModel.sessionId != nil, viewModel.completion == nil {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.start()
            }
            .task(id: viewModel.completion?.sessionScore) {
                guard viewModel.completion != nil else {
                    relatedScenario = nil
                    return
                }
                relatedScenario = await viewModel.nextScenario(
                    roleTrack: appState.selectedRoleTrack,
                    experienceLevel: appState.experienceLevel
                )
            }
            .sheet(isPresented: $viewModel.paywallRequired) {
                PaywallView(dependencies: dependencies, reason: viewModel.paywallReason)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TalkTrackTheme.ink)
                    .frame(width: 42, height: 42)
                    .background(Color.white, in: Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(context.sessionType == .full ? "Full Session" : "Quick Drill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.96, green: 0.98, blue: 0.92), in: Capsule())
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(context.mode.title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.muted)
            Text(context.scenario.promptText)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text(promptGuidance)
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)
        }
        .padding(22)
        .talkTrackCard(radius: 30)
    }

    private var recorderStage: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                statusChip(title: "Rep", value: "\(viewModel.currentRepIndex)/\(viewModel.maxReps)")
                statusChip(title: "Time", value: "\(Int(viewModel.elapsed))s")
                statusChip(title: "Next", value: viewModel.statusDetail)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.stageTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text(viewModel.stageMessage)
                    .font(.subheadline)
                    .foregroundStyle(TalkTrackTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(LinearGradient(colors: [TalkTrackTheme.accentGreenSoft, Color.white], startPoint: .top, endPoint: .bottom))
                        .frame(height: 250)

                    VStack(spacing: 18) {
                        Spacer(minLength: 14)
                        TalkTrackWaveView()
                            .frame(height: 88)
                            .padding(.horizontal, 16)

                        Button {
                            Task { await viewModel.toggleRecording() }
                        } label: {
                            Circle()
                                .fill(viewModel.isRecording ? TalkTrackTheme.indigo : TalkTrackTheme.accentGreen)
                                .frame(width: 106, height: 106)
                                .overlay(
                                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 38, weight: .bold))
                                        .foregroundStyle(Color.white)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isBusy || viewModel.sessionId == nil)

                        Text(controlCaption)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(TalkTrackTheme.ink)

                        Spacer(minLength: 8)
                    }
                }

                if viewModel.isBusy {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(TalkTrackTheme.indigo)
                        Text(viewModel.busyMessage)
                            .font(.subheadline)
                            .foregroundStyle(TalkTrackTheme.muted)
                    }
                } else if viewModel.shouldShowRetryAction {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Retry with one clear change")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(TalkTrackTheme.ink)
                        Text(viewModel.latestFeedback?.retryInstruction ?? "Use the coaching above, then record the answer again.")
                            .font(.subheadline)
                            .foregroundStyle(TalkTrackTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        actionButton(title: viewModel.retryButtonTitle, filled: true) {
                            Task { await viewModel.startRetry() }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else if let feedback = viewModel.latestFeedback, viewModel.completion == nil {
                    Text(feedback.retryInstruction)
                        .font(.subheadline)
                        .foregroundStyle(TalkTrackTheme.muted)
                } else {
                    Text(viewModel.stageMessage)
                        .font(.subheadline)
                        .foregroundStyle(TalkTrackTheme.muted)
                }
            }
        }
        .padding(22)
        .talkTrackCard(radius: 32)
    }

    private var unavailableStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Practice is not ready")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            Text(viewModel.errorMessage ?? "We could not prepare this session yet.")
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            actionButton(title: "Try again", filled: true) {
                Task { await viewModel.start() }
            }
        }
        .padding(22)
        .talkTrackCard(radius: 32)
    }

    private func beforeAfterCard(_ pair: (before: SpeakingRep, after: SpeakingRep)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TalkTrackSectionHeader(title: "Before vs after")
            Text(viewModel.improvementHeadline)
                .font(.subheadline)
                .foregroundStyle(TalkTrackTheme.muted)

            comparisonBlock(title: "First try", rep: pair.before)
            comparisonBlock(title: "Latest try", rep: pair.after)
        }
        .padding(22)
        .talkTrackCard(radius: 30)
    }

    private var repTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            TalkTrackSectionHeader(title: "Rep timeline")

            ForEach(viewModel.reps) { rep in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rep \(rep.repIndex)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(TalkTrackTheme.ink)
                        Spacer()
                        Text("Score \(rep.score)")
                            .font(.subheadline.weight(.semibold))
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
                .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .padding(22)
        .talkTrackCard(radius: 30)
    }

    private func completionCard(_ completion: CompleteSessionResponse) -> some View {
        let primaryAction = resolvedPrimaryCompletionAction(hasRelatedScenario: relatedScenario != nil)
        let secondaryAction = alternateCompletionAction(for: primaryAction, hasRelatedScenario: relatedScenario != nil)

        return VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.completionTitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.muted)
            Text(viewModel.improvementHeadline)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            HStack(spacing: 12) {
                TalkTrackStatChip(title: "Final", value: "\(completion.sessionScore)")
                TalkTrackStatChip(title: "Delta", value: completion.improvementDelta >= 0 ? "+\(completion.improvementDelta)" : "\(completion.improvementDelta)")
                TalkTrackStatChip(title: "7d avg", value: "\(Int(completion.trendSnapshot.avgScore7d.rounded()))")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.completionChangeTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text(viewModel.completionChangeSummary)
                    .font(.subheadline)
                    .foregroundStyle(TalkTrackTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(viewModel.completionChangeDetail)
                    .font(.subheadline)
                    .foregroundStyle(TalkTrackTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Best next move")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text(viewModel.completionActionDetail(primaryAction))
                    .font(.subheadline)
                    .foregroundStyle(TalkTrackTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actionButton(title: viewModel.completionActionTitle(primaryAction), filled: true) {
                runCompletionAction(primaryAction, nextScenario: relatedScenario)
            }

            if let secondaryAction {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or do this instead")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                    Text(viewModel.completionActionDetail(secondaryAction))
                        .font(.subheadline)
                        .foregroundStyle(TalkTrackTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    actionButton(title: viewModel.completionActionTitle(secondaryAction), filled: false) {
                        runCompletionAction(secondaryAction, nextScenario: relatedScenario)
                    }
                }
            }

            actionButton(title: viewModel.isBestAnswerSaved ? "Saved on this device" : "Save this answer on this device", filled: false) {
                viewModel.saveBestAnswer()
            }

            Button("Back to Home") {
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(TalkTrackTheme.muted)
            .buttonStyle(.plain)
        }
        .padding(22)
        .talkTrackCard(radius: 30)
    }

    private func comparisonBlock(title: String, rep: SpeakingRep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Spacer()
                Text("Score \(rep.score)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TalkTrackTheme.muted)
            }
            Text(rep.shortTranscript)
                .font(.callout)
                .foregroundStyle(TalkTrackTheme.ink)
            Text(rep.feedback.strength)
                .font(.footnote)
                .foregroundStyle(TalkTrackTheme.muted)
        }
        .padding(16)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func statusChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(TalkTrackTheme.muted)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionButton(title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(filled ? Color.white : TalkTrackTheme.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(filled ? TalkTrackTheme.indigo : Color.white.opacity(0.92), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var controlCaption: String {
        viewModel.controlCaption
    }

    private var promptGuidance: String {
        if context.sessionType == .quick {
            return "Give one sharp answer in \(context.scenario.recommendedDurationLabel). This is a fast single-rep drill."
        }
        return "You’ll do three coached reps. Aim for \(context.scenario.recommendedDurationLabel), and keep each retry tighter than the last."
    }

    private func resolvedPrimaryCompletionAction(hasRelatedScenario: Bool) -> PracticeSessionViewModel.CompletionAction {
        if viewModel.recommendedCompletionAction == .relatedScenario, !hasRelatedScenario {
            return .quickDrill
        }
        return viewModel.recommendedCompletionAction
    }

    private func alternateCompletionAction(
        for primaryAction: PracticeSessionViewModel.CompletionAction,
        hasRelatedScenario: Bool
    ) -> PracticeSessionViewModel.CompletionAction? {
        switch primaryAction {
        case .relatedScenario:
            return .quickDrill
        case .quickDrill:
            return hasRelatedScenario ? .relatedScenario : nil
        }
    }

    private func runCompletionAction(
        _ action: PracticeSessionViewModel.CompletionAction,
        nextScenario: Scenario?
    ) {
        switch action {
        case .relatedScenario:
            guard let nextScenario else { return }
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                appState.activeSessionContext = SessionContext(mode: context.mode, scenario: nextScenario, sessionType: .full)
            }
        case .quickDrill:
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                appState.activeSessionContext = SessionContext(mode: context.mode, scenario: context.scenario, sessionType: .quick)
            }
        }
    }
}
