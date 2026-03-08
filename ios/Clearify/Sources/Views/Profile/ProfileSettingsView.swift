import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var preferredName = ""
    @State private var experienceLevel: ExperienceLevel = .zeroToOneYears
    @State private var selectedFocus: CoachingFocus = .clarity
    @State private var selectedMode: ScenarioMode = .workplace
    @State private var selectedRoleTrack: RoleTrack = .general
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoadInitialValues = false

    let dependencies: Dependencies

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    nameCard
                    experienceCard
                    focusCard
                    modeCard
                    roleTrackCard

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(TalkTrackBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .task {
            guard !didLoadInitialValues else { return }
            didLoadInitialValues = true
            preferredName = appState.preferredFirstName
            experienceLevel = appState.experienceLevel
            selectedFocus = appState.selfReportedFocus
            selectedMode = appState.selectedMode
            selectedRoleTrack = appState.selectedRoleTrack
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("First name")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            TextField("First name", text: $preferredName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .talkTrackCard(radius: 18)
        }
        .padding(20)
        .talkTrackCard(radius: 28)
    }

    private var experienceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experience level")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            ForEach(ExperienceLevel.allCases) { level in
                Button {
                    experienceLevel = level
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: experienceLevel == level ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(experienceLevel == level ? TalkTrackTheme.indigo : TalkTrackTheme.muted)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.title)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(TalkTrackTheme.ink)
                            Text(level.subtitle)
                                .font(.footnote)
                                .foregroundStyle(TalkTrackTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .talkTrackCard(radius: 28)
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Primary coaching focus")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CoachingFocus.allCases) { focus in
                    Button {
                        selectedFocus = focus
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(focus.title)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(TalkTrackTheme.ink)
                            Text(focus.planDetail)
                                .font(.footnote)
                                .foregroundStyle(TalkTrackTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                        .padding(14)
                        .background(
                            selectedFocus == focus ? TalkTrackTheme.blush.opacity(0.78) : Color.white.opacity(0.82),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .talkTrackCard(radius: 28)
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Default practice mode")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(ScenarioMode.allCases) { mode in
                    TalkTrackModePill(title: mode.title, isSelected: selectedMode == mode) {
                        selectedMode = mode
                    }
                }
            }
        }
        .padding(20)
        .talkTrackCard(radius: 28)
    }

    private var roleTrackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Role track")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(RoleTrack.allCases) { role in
                    Button {
                        selectedRoleTrack = role
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(role.title)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(TalkTrackTheme.ink)
                            Text(role.subtitle)
                                .font(.footnote)
                                .foregroundStyle(TalkTrackTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
                        .padding(14)
                        .background(
                            selectedRoleTrack == role ? TalkTrackTheme.blush.opacity(0.78) : Color.white.opacity(0.82),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .talkTrackCard(radius: 28)
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await ProfileSettingsSubmission.save(
                preferredName: preferredName,
                experienceLevel: experienceLevel,
                focus: selectedFocus,
                mode: selectedMode,
                roleTrack: selectedRoleTrack,
                using: dependencies.userProfileService,
                appState: appState
            )
            dismiss()
        } catch {
            dependencies.telemetry.record(error: error, context: "profile_settings_save")
            errorMessage = UserFacingErrorMessage.profileSettings(error)
        }
    }
}
