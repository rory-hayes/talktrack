import SwiftUI

struct OnboardingView: View {
    private enum AccountField: Hashable {
        case email
        case password
    }

    @EnvironmentObject private var appState: AppState
    @ObservedObject private var onboardingDebug = OnboardingDebugDiagnostics.shared
    @StateObject private var viewModel: OnboardingViewModel
    @AppStorage("clearify.onboarding.step") private var persistedStepRawValue = OnboardingStep.introPractice.rawValue
    @AppStorage("clearify.onboarding.authProgressStep") private var persistedAuthenticatedStepRawValue = OnboardingStep.account.rawValue
    @State private var email = ""
    @State private var password = ""
    @State private var isAuthenticating = false
    @State private var authMessage: String?
    @State private var lastFooterTapTimestamp: CFTimeInterval = 0
    @FocusState private var focusedAccountField: AccountField?

    private let dependencies: Dependencies
    private let modeColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    private let focusColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let roleColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(dependencies: dependencies))
    }

    private var step: OnboardingStep {
        get { OnboardingStep(rawValue: persistedStepRawValue) ?? .introPractice }
        nonmutating set { persistedStepRawValue = newValue.rawValue }
    }

    private var authenticatedProgressStep: OnboardingStep {
        get {
            guard let restored = OnboardingStep(rawValue: persistedAuthenticatedStepRawValue) else {
                return .account
            }
            return restored.isIntro ? .account : restored
        }
        nonmutating set {
            persistedAuthenticatedStepRawValue = max(newValue, .account).rawValue
        }
    }

    var body: some View {
        ZStack {
            TalkTrackBackground()

            if step.isIntro, let page = step.introPage {
                introStep(page)
                    .padding(.horizontal, 24)
                    .padding(.top, 42)
                    .padding(.bottom, 12)
                    .safeAreaInset(edge: .bottom) {
                        footer
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ZStack(alignment: .bottom) {
                    setupFlow
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.bottom, setupFooterReservedHeight)
                        .mask(Rectangle())
                        .zIndex(0)

                    fixedSetupFooter
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                        .zIndex(1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            onboardingDebugLabel
        }
        .task {
            dependencies.telemetry.logOnboardingStarted()
            syncDebugState()
            onboardingDebug.record("onboarding_task_start authUserPresent=\(dependencies.authService.user != nil)")
            hydrateDraftFromAppState(reason: "onboarding_task_start")
            if dependencies.authService.user != nil {
                restoreAuthenticatedProgress(reason: "task_authenticated_restore")
            } else {
                resetAuthenticatedProgress(reason: "task_signed_out_reset")
                setStep(.introPractice, reason: "task_signed_out_reset")
            }
            syncDebugState()
        }
        .onChange(of: dependencies.authService.user?.uid) { _, newUID in
            onboardingDebug.record("auth_uid_change hasUser=\(newUID != nil)")
            if newUID != nil, !appState.isOnboardingComplete {
                hydrateDraftFromAppState(reason: "auth_uid_change_restore")
                withAnimation {
                    restoreAuthenticatedProgress(reason: "auth_uid_change_restore")
                }
            } else if newUID == nil {
                withAnimation {
                    resetAuthenticatedProgress(reason: "auth_uid_change_signed_out")
                    setStep(.introPractice, reason: "auth_uid_change_signed_out")
                }
            }
            syncDebugState()
        }
        .onChange(of: step) { _, newStep in
            onboardingDebug.record("visible_step_changed to=\(newStep.debugName)")
            syncDebugState()
            if newStep == .profile {
                hydrateDraftFromAppState(reason: "visible_step_profile")
            }
        }
        .onChange(of: viewModel.isSubmitting) { _, newValue in
            onboardingDebug.record("submission_state_changed isSubmitting=\(newValue)")
            syncDebugState()
        }
        .onChange(of: isAuthenticating) { _, newValue in
            onboardingDebug.record("auth_submission_state_changed isAuthenticating=\(newValue)")
            syncDebugState()
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: step)
    }

    private func introStep(_ page: IntroPageContent) -> some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Skip") {
                        withAnimation {
                            setStep(
                                dependencies.authService.user == nil ? .account : .profile,
                                reason: "intro_skip"
                            )
                        }
                    }
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.95), in: Capsule())

                    Spacer()
                }
                .zIndex(2)

                introArtwork(for: step)
                    .zIndex(1)

                VStack(alignment: .leading, spacing: 8) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(page.subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(page.bullets, id: \.self) { bullet in
                        introBulletRow(bullet)
                    }
                }

                introDots
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.63, green: 0.43, blue: 0.96), Color(red: 0.46, green: 0.30, blue: 0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 42, style: .continuous)
            )
            .shadow(color: TalkTrackTheme.indigo.opacity(0.18), radius: 26, y: 16)
        }
    }

    private var setupFlow: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                progressIndicator

                switch step {
                case .account:
                    accountStep
                case .profile:
                    profileStep
                case .focus:
                    focusStep
                default:
                    EmptyView()
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.bottom, 24)
        }
        .contentShape(Rectangle())
        .clipped()
    }

    private var topBar: some View {
        HStack {
            Button {
                withAnimation {
                    if let previous = step.previous {
                        setStep(previous, reason: "topbar_back")
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TalkTrackTheme.ink)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.92), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Circle()
                .fill(LinearGradient(colors: [TalkTrackTheme.lavender, TalkTrackTheme.sky], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: topBarSymbol).foregroundStyle(Color.white))
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.questionSteps) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? TalkTrackTheme.indigo : Color.white.opacity(0.72))
                    .frame(height: 8)
            }
        }
        .padding(12)
        .talkTrackCard(radius: 20)
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set up your profile")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text("We use this to tailor your first prompt and the kind of coaching you get.")
                    .font(.subheadline)
                    .foregroundStyle(TalkTrackTheme.muted)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("What should we call you?")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)

                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(TalkTrackTheme.muted)
                    TextField("First name", text: $viewModel.preferredName)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .talkTrackCard(radius: 22)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Where are you in your career?")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)

                ForEach(ExperienceLevel.allCases) { level in
                    selectionRow(
                        title: level.title,
                        subtitle: level.subtitle,
                        isSelected: viewModel.experienceLevel == level
                    ) {
                        viewModel.experienceLevel = level
                    }
                }
            }
            .padding(20)
            .talkTrackCard(radius: 30)

            VStack(alignment: .leading, spacing: 14) {
                Text("What do you want help with first?")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)

                LazyVGrid(columns: focusColumns, spacing: 12) {
                    ForEach(CoachingFocus.allCases) { focus in
                        focusCard(focus)
                    }
                }
            }
            .padding(20)
            .talkTrackCard(radius: 30)
        }
    }

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create your account")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text("Use Google or email so your coaching profile and plan stay linked to your account from day one.")
                    .font(.subheadline)
                    .foregroundStyle(TalkTrackTheme.muted)
            }

            VStack(alignment: .leading, spacing: 14) {
                if let user = dependencies.authService.user {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Signed in")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(TalkTrackTheme.indigo)
                        Text(user.email ?? user.displayName ?? "Account connected")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(TalkTrackTheme.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .talkTrackCard(radius: 24)
                } else {
                    Button {
                        Task { await continueWithGoogle() }
                    } label: {
                        if isAuthenticating {
                            ProgressView()
                                .tint(TalkTrackTheme.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            HStack(spacing: 12) {
                                Text("G")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(TalkTrackTheme.ink)
                                    .frame(width: 28, height: 28)
                                    .background(Color.white, in: Circle())
                                Text("Continue with Google")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(TalkTrackTheme.ink)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                    }
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("or continue with email")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(TalkTrackTheme.muted)

                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.emailAddress)
                            .submitLabel(.next)
                            .focused($focusedAccountField, equals: .email)
                            .onSubmit {
                                focusedAccountField = .password
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .talkTrackCard(radius: 18)

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .submitLabel(.done)
                            .focused($focusedAccountField, equals: .password)
                            .onSubmit {
                                Task { await createEmailAccount() }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .talkTrackCard(radius: 18)

                        Button {
                            Task { await createEmailAccount() }
                        } label: {
                            if isAuthenticating {
                                ProgressView()
                                    .tint(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text("Create account with email")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                        .background(TalkTrackTheme.indigo, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }

                Text("You can update your name, focus, mode, and role pack later from Settings.")
                    .font(.footnote)
                    .foregroundStyle(TalkTrackTheme.muted)

                if let authMessage {
                    Text(authMessage)
                        .font(.footnote)
                        .foregroundStyle(TalkTrackTheme.indigo)
                }
            }
            .padding(20)
            .talkTrackCard(radius: 28)
        }
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose your training path")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text("This decides what appears on your dashboard and which prompts get recommended first.")
                    .font(.subheadline)
                    .foregroundStyle(TalkTrackTheme.muted)
            }

            LazyVGrid(columns: modeColumns, spacing: 8) {
                ForEach(ScenarioMode.allCases) { mode in
                    TalkTrackModePill(title: mode.title, isSelected: viewModel.selectedMode == mode) {
                        viewModel.selectedMode = mode
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(8)
            .talkTrackCard(radius: 26)

            VStack(alignment: .leading, spacing: 14) {
                TalkTrackSectionHeader(title: "Role pack")

                LazyVGrid(columns: roleColumns, spacing: 12) {
                    ForEach(RoleTrack.allCases) { role in
                        roleCard(role)
                    }
                }
            }
            .padding(18)
            .talkTrackCard(radius: 30)
        }
    }

    private var fixedSetupFooter: some View {
        ZStack(alignment: .top) {
            footerContent
                .allowsHitTesting(false)

            Button {
                handleFooterTap()
            } label: {
                Color.black.opacity(0.001)
                    .frame(maxWidth: .infinity)
                    .frame(height: setupFooterReservedHeight)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    handleFooterTap()
                }
            )
            .accessibilityIdentifier(step.footerAccessibilityIdentifier)
            .accessibilityLabel(step.ctaTitle)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        Button {
            handleFooterTap()
        } label: {
            footerContent
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                handleFooterTap()
            }
        )
        .accessibilityIdentifier(step.footerAccessibilityIdentifier)
        .accessibilityLabel(step.ctaTitle)
    }

    private var footerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(step.isIntro ? TalkTrackTheme.indigo : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                } else {
                    Text(step.ctaTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(step.isIntro ? TalkTrackTheme.indigo : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            }
            .contentShape(Capsule())
            .background(step.isIntro ? Color.white : TalkTrackTheme.indigo, in: Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)

            if !step.footerNote.isEmpty {
                Text(step.footerNote)
                    .font(.caption)
                    .foregroundStyle(step.isIntro ? Color.white.opacity(0.84) : TalkTrackTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var topBarSymbol: String {
        switch step {
        case .account:
            return "person.badge.key.fill"
        case .profile:
            return "person.crop.circle.badge.plus"
        case .focus:
            return "waveform"
        default:
            return "waveform"
        }
    }

    private var currentAuthenticatedEntryStep: OnboardingStep {
        max(authenticatedProgressStep, .profile)
    }

    private var onboardingDebugLabel: some View {
        Group {
            if onboardingDebug.isEnabled {
                VStack(alignment: .leading, spacing: 1) {
                    Text(onboardingDebug.stateSummary)
                        .accessibilityIdentifier(OnboardingDebugDiagnostics.stateAccessibilityIdentifier)
                        .accessibilityLabel(onboardingDebug.stateSummary)
                    Text(onboardingDebug.eventsSummary)
                        .accessibilityIdentifier(OnboardingDebugDiagnostics.eventsAccessibilityIdentifier)
                        .accessibilityLabel(onboardingDebug.eventsSummary)
                }
                .font(.system(size: 1))
                .foregroundStyle(Color.black.opacity(0.01))
                .padding(1)
            }
        }
    }

    private var setupFooterReservedHeight: CGFloat {
        step.footerNote.isEmpty ? 108 : 152
    }

    private func restoreAuthenticatedProgress(reason: String) {
        let target = currentAuthenticatedEntryStep
        onboardingDebug.record(
            "restore_authenticated_progress_enter reason=\(reason) visibleStep=\(step.debugName) authStep=\(authenticatedProgressStep.debugName) target=\(target.debugName)"
        )
        setStep(target, reason: reason)
        onboardingDebug.record(
            "restore_authenticated_progress_result reason=\(reason) visibleStep=\(step.debugName) authStep=\(authenticatedProgressStep.debugName)"
        )
    }

    private func advanceAuthenticatedProgress(to nextStep: OnboardingStep, reason: String) {
        let resolvedStep = max(nextStep, currentAuthenticatedEntryStep)
        onboardingDebug.record(
            "advance_authenticated_progress_enter reason=\(reason) visibleStep=\(step.debugName) authStep=\(authenticatedProgressStep.debugName) requested=\(nextStep.debugName) resolved=\(resolvedStep.debugName)"
        )
        onboardingDebug.record(
            "advance_authenticated_progress_write_auth_step reason=\(reason) target=\(resolvedStep.debugName)"
        )
        setAuthenticatedProgressStep(resolvedStep, reason: reason)
        onboardingDebug.record(
            "advance_authenticated_progress_write_step reason=\(reason) target=\(resolvedStep.debugName)"
        )
        setStep(resolvedStep, reason: reason)
    }

    private func resetAuthenticatedProgress(reason: String) {
        setAuthenticatedProgressStep(.account, reason: reason)
    }

    private func hydrateDraftFromAppState(reason: String) {
        let resolvedPreferredName = resolvePreferredName(
            existingName: appState.preferredFirstName,
            displayName: dependencies.authService.user?.displayName,
            email: dependencies.authService.user?.email
        )

        if !resolvedPreferredName.isEmpty {
            viewModel.preferredName = resolvedPreferredName
        }
        viewModel.experienceLevel = appState.experienceLevel
        viewModel.selectedFocus = appState.selfReportedFocus
        viewModel.selectedMode = appState.selectedMode
        viewModel.selectedRoleTrack = appState.selectedRoleTrack
        onboardingDebug.record(
            "appstate_hydrate_onboarding_restore reason=\(reason) nameEmpty=\(viewModel.trimmedPreferredName.isEmpty) mode=\(viewModel.selectedMode.rawValue) role=\(viewModel.selectedRoleTrack.rawValue)"
        )
        syncDebugState()
    }

    private var introDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == step.introIndex ? Color.white : Color.white.opacity(0.45))
                    .frame(width: index == step.introIndex ? 12 : 10, height: index == step.introIndex ? 12 : 10)
            }
        }
    }

    private func introArtwork(for step: OnboardingStep) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(height: 176)

            switch step {
            case .introPractice:
                VStack(alignment: .leading, spacing: 12) {
                    TalkTrackScenarioArtwork(mode: .interview)
                        .frame(height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    HStack(spacing: 10) {
                        introMiniCard(title: "Interview", subtitle: "Tell me about yourself")
                        introMiniCard(title: "Meetings", subtitle: "Give a quick project update")
                    }
                }
                .padding(16)
            case .introCoach:
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Score 74")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(TalkTrackTheme.ink)
                            Text("Get to the point sooner")
                                .font(.footnote)
                                .foregroundStyle(TalkTrackTheme.muted)
                        }
                        Spacer()
                        Text("Steady pace")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(TalkTrackTheme.sky)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    TalkTrackWaveView(color: Color.white)
                        .frame(height: 48)
                }
                .padding(16)
            case .introProgress:
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        introStat(title: "Streak", value: "4d")
                        introStat(title: "Avg", value: "78")
                        introStat(title: "Saved", value: "3")
                    }
                    SparklineChart(values: [62, 68, 70, 75, 78], lineColor: Color.white)
                        .frame(height: 48)
                        .padding(12)
                        .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    introMiniCard(title: "Best answer", subtitle: "Replay your strongest answer")
                }
                .padding(16)
            default:
                EmptyView()
            }
        }
    }

    private func introMiniCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(TalkTrackTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func introStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.78))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func introBulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .frame(width: 18, alignment: .center)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .fill(isSelected ? TalkTrackTheme.indigo : Color.white)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(TalkTrackTheme.indigo.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(TalkTrackTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(16)
            .background(
                isSelected ? TalkTrackTheme.blush.opacity(0.75) : Color.white.opacity(0.78),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func focusCard(_ focus: CoachingFocus) -> some View {
        Button {
            viewModel.selectedFocus = focus
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(focus.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text(focus.planDetail)
                    .font(.footnote)
                    .foregroundStyle(TalkTrackTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .padding(14)
            .background(
                viewModel.selectedFocus == focus ? TalkTrackTheme.blush.opacity(0.78) : Color.white.opacity(0.82),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(viewModel.selectedFocus == focus ? TalkTrackTheme.indigo.opacity(0.26) : Color.white.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func roleCard(_ role: RoleTrack) -> some View {
        Button {
            viewModel.selectedRoleTrack = role
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(role.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text(role.subtitle)
                    .font(.footnote)
                    .foregroundStyle(TalkTrackTheme.muted)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .padding(14)
            .background(
                viewModel.selectedRoleTrack == role
                    ? LinearGradient(colors: [Color.white, TalkTrackTheme.blush.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.96), Color.white.opacity(0.84)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(viewModel.selectedRoleTrack == role ? TalkTrackTheme.indigo.opacity(0.22) : Color.white.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func handleFooterTap() {
        let now = CACurrentMediaTime()
        if now - lastFooterTapTimestamp < 0.35 {
            onboardingDebug.record("footer_tap_ignored reason=debounced step=\(step.debugName)")
            return
        }
        lastFooterTapTimestamp = now
        onboardingDebug.record("footer_tap_enter step=\(step.debugName)")
        syncDebugState()

        switch step {
        case .introPractice, .introCoach, .introProgress:
            if let next = step.next {
                withAnimation { setStep(next, reason: "footer_intro_continue") }
            }
        case .account:
            if dependencies.authService.user != nil {
                viewModel.errorMessage = nil
                onboardingDebug.record("footer_account_continue signedIn=true")
                withAnimation { restoreAuthenticatedProgress(reason: "footer_account_signed_in_continue") }
                return
            }

            if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !password.isEmpty {
                onboardingDebug.record("footer_account_continue starting_email_auth")
                Task { await createEmailAccount() }
                return
            }

            onboardingDebug.record("footer_account_continue blocked_missing_credentials")
            guard dependencies.authService.user != nil else {
                viewModel.errorMessage = "Create your account to continue."
                return
            }
        case .profile:
            let resolvedPreferredName = resolvePreferredName(
                existingName: viewModel.preferredName,
                displayName: dependencies.authService.user?.displayName,
                email: dependencies.authService.user?.email
            )
            if resolvedPreferredName != viewModel.preferredName {
                viewModel.preferredName = resolvedPreferredName
                onboardingDebug.record("profile_name_resolved_from_auth fallbackApplied=true")
            }
            onboardingDebug.record(
                "footer_profile_continue nameEmpty=\(resolvedPreferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)"
            )
            guard viewModel.validateProfileStep() else { return }
            withAnimation { advanceAuthenticatedProgress(to: .focus, reason: "footer_profile_continue") }
        case .focus:
            onboardingDebug.record("footer_focus_continue start_finish_onboarding")
            Task { await finishOnboarding() }
        }
    }

    private func createEmailAccount() async {
        onboardingDebug.record("email_auth_start")
        focusedAccountField = nil
        await Task.yield()

        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            onboardingDebug.record("email_auth_validation_failed missing_email")
            viewModel.errorMessage = "Add an email to create your account."
            return
        }
        guard password.count >= 6 else {
            onboardingDebug.record("email_auth_validation_failed short_password")
            viewModel.errorMessage = "Use a password with at least 6 characters."
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            try await dependencies.authService.signInWithEmail(email: email, password: password)
            try await dependencies.userProfileService.refreshIdentityFields()
            authMessage = "Account ready. Continue to build your profile."
            viewModel.errorMessage = nil
            onboardingDebug.record("email_auth_success")
            withAnimation { advanceAuthenticatedProgress(to: .profile, reason: "email_auth_success") }
        } catch {
            onboardingDebug.record("email_auth_failed type=\(String(describing: type(of: error)))")
            dependencies.telemetry.record(error: error, context: "onboarding_email_auth")
            viewModel.errorMessage = UserFacingErrorMessage.onboardingAuth(error)
        }
    }

    private func continueWithGoogle() async {
        onboardingDebug.record("google_auth_start")
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            try await dependencies.authService.signInWithGoogle()
            try await dependencies.userProfileService.refreshIdentityFields()
            authMessage = "Account ready. Continue to build your profile."
            viewModel.errorMessage = nil
            onboardingDebug.record("google_auth_success")
            withAnimation { advanceAuthenticatedProgress(to: .profile, reason: "google_auth_success") }
        } catch {
            onboardingDebug.record("google_auth_failed type=\(String(describing: type(of: error)))")
            dependencies.telemetry.record(error: error, context: "onboarding_google_auth")
            viewModel.errorMessage = UserFacingErrorMessage.onboardingAuth(error)
        }
    }

    private func finishOnboarding() async {
        onboardingDebug.record("finish_onboarding_start")
        viewModel.isSubmitting = true
        defer { viewModel.isSubmitting = false }

        do {
            _ = try await viewModel.completeOnboarding()
            appState.markOnboardingComplete(
                preferredFirstName: viewModel.trimmedPreferredName,
                experienceLevel: viewModel.experienceLevel,
                selfReportedFocus: viewModel.selectedFocus,
                mode: viewModel.selectedMode,
                roleTrack: viewModel.selectedRoleTrack
            )
            resetAuthenticatedProgress(reason: "finish_onboarding_success")
            setStep(.introPractice, reason: "finish_onboarding_success_reset")
            appState.selectedTab = .home
            onboardingDebug.record("finish_onboarding_success")
        } catch {
            onboardingDebug.record("finish_onboarding_failed type=\(String(describing: type(of: error)))")
            dependencies.telemetry.record(error: error, context: "onboarding_complete")
            viewModel.errorMessage = UserFacingErrorMessage.onboardingSetup(error)
        }
    }

    private func setStep(_ newStep: OnboardingStep, reason: String) {
        let previous = step
        persistedStepRawValue = newStep.rawValue
        onboardingDebug.updateState(step: newStep.debugName)
        onboardingDebug.record("step_write reason=\(reason) from=\(previous.debugName) to=\(newStep.debugName)")
    }

    private func setAuthenticatedProgressStep(_ newStep: OnboardingStep, reason: String) {
        let previous = authenticatedProgressStep
        persistedAuthenticatedStepRawValue = max(newStep, .account).rawValue
        onboardingDebug.updateState(authenticatedProgressStep: authenticatedProgressStep.debugName)
        onboardingDebug.record(
            "auth_progress_write reason=\(reason) from=\(previous.debugName) to=\(authenticatedProgressStep.debugName)"
        )
    }

    private func syncDebugState() {
        onboardingDebug.updateState(
            step: step.debugName,
            authenticatedProgressStep: authenticatedProgressStep.debugName,
            isSubmitting: viewModel.isSubmitting,
            isAuthenticating: isAuthenticating
        )
    }
}

private struct IntroPageContent {
    let title: String
    let subtitle: String
    let bullets: [String]
}

private enum OnboardingStep: Int, CaseIterable, Identifiable, Comparable {
    case introPractice
    case introCoach
    case introProgress
    case account
    case profile
    case focus

    var id: Int { rawValue }

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var isIntro: Bool {
        switch self {
        case .introPractice, .introCoach, .introProgress:
            return true
        case .account, .profile, .focus:
            return false
        }
    }

    var introIndex: Int {
        switch self {
        case .introPractice: return 0
        case .introCoach: return 1
        case .introProgress: return 2
        default: return 0
        }
    }

    static var questionSteps: [OnboardingStep] {
        [.account, .profile, .focus]
    }

    var next: OnboardingStep? {
        switch self {
        case .introPractice:
            return .introCoach
        case .introCoach:
            return .introProgress
        case .introProgress:
            return .account
        case .account:
            return .profile
        case .profile:
            return .focus
        case .focus:
            return nil
        }
    }

    var previous: OnboardingStep? {
        switch self {
        case .introPractice:
            return nil
        case .introCoach:
            return .introPractice
        case .introProgress:
            return .introCoach
        case .account:
            return .introProgress
        case .profile:
            return .account
        case .focus:
            return .profile
        }
    }

    var ctaTitle: String {
        switch self {
        case .introPractice, .introCoach:
            return "Continue"
        case .introProgress:
            return "Set up my plan"
        case .account:
            return "Continue"
        case .profile:
            return "Continue"
        case .focus:
            return "Go to dashboard"
        }
    }

    var footerNote: String {
        switch self {
        case .introPractice:
            return ""
        case .introCoach:
            return ""
        case .introProgress:
            return ""
        case .account:
            return "You need an account before we save your coaching profile."
        case .profile:
            return "These answers personalize the prompts and examples you see first."
        case .focus:
            return "Your dashboard will be ready as soon as we save your profile."
        }
    }

    var footerAccessibilityIdentifier: String {
        switch self {
        case .introPractice:
            return "onboarding.footer.introPractice"
        case .introCoach:
            return "onboarding.footer.introCoach"
        case .introProgress:
            return "onboarding.footer.introProgress"
        case .account:
            return "onboarding.footer.account"
        case .profile:
            return "onboarding.footer.profile"
        case .focus:
            return "onboarding.footer.focus"
        }
    }

    var debugName: String {
        switch self {
        case .introPractice:
            return "introPractice"
        case .introCoach:
            return "introCoach"
        case .introProgress:
            return "introProgress"
        case .account:
            return "account"
        case .profile:
            return "profile"
        case .focus:
            return "focus"
        }
    }

    var introPage: IntroPageContent? {
        switch self {
        case .introPractice:
            return IntroPageContent(
                title: "Practice real work moments",
                subtitle: "Train for the conversations that matter at work.",
                bullets: [
                    "Interview answers and resume walkthroughs",
                    "Standups, project updates, and manager questions",
                    "Client and stakeholder conversations"
                ]
            )
        case .introCoach:
            return IntroPageContent(
                title: "Get one clear coaching point",
                subtitle: "After each answer, Clearify highlights the next fix.",
                bullets: [
                    "One score for structure, clarity, conciseness, and delivery",
                    "One main improvement and a better answer structure",
                    "One rewritten example and one retry instruction"
                ]
            )
        case .introProgress:
            return IntroPageContent(
                title: "See progress build daily",
                subtitle: "Short daily reps turn into improvement you can see.",
                bullets: [
                    "Streaks and weekly score trend",
                    "Saved answers and before-versus-after comparisons",
                    "Recommended prompts based on your weak spots"
                ]
            )
        case .account, .profile, .focus:
            return nil
        }
    }
}
