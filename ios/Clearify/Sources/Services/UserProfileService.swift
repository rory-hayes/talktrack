import FirebaseAuth
import FirebaseFirestore
import Foundation

func resolvePreferredName(existingName: String?, displayName: String?, email: String?) -> String {
    if let existingName {
        let trimmed = existingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed.caseInsensitiveCompare("there") != .orderedSame {
            return trimmed
        }
    }

    if let displayName {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed.components(separatedBy: .whitespacesAndNewlines).first ?? trimmed
        }
    }

    if let email {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed.split(separator: "@").first.map(String.init) ?? ""
        }
    }

    return ""
}

enum UserProfileServiceError: LocalizedError {
    case missingPreferredName

    var errorDescription: String? {
        switch self {
        case .missingPreferredName:
            return "Add your first name before saving your profile."
        }
    }
}

final class UserProfileService {
    private let db = Firestore.firestore()
    private let defaults = UserDefaults.standard
    private let syncTimeout: TimeInterval = 4
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func fetchCurrentProfile() async throws -> UserProfileRecord? {
        guard let user = Auth.auth().currentUser else {
            OnboardingDebugDiagnostics.recordFromAnyActor("profile_fetch_skipped missing_auth_user")
            return nil
        }

        let cachedProfile = normalizedProfile(cachedProfile(for: user.uid), for: user)
        if let cachedProfile {
            OnboardingDebugDiagnostics.recordFromAnyActor(
                "profile_fetch_cached hasCompleted=\(cachedProfile.hasCompletedOnboarding)"
            )
            Task {
                await refreshRemoteProfile(for: user)
            }
            return cachedProfile
        }

        do {
            OnboardingDebugDiagnostics.recordFromAnyActor("profile_fetch_remote_start")
            let snapshot = try await fetchRemoteSnapshot(for: user.uid)
            guard let data = snapshot.data() else {
                OnboardingDebugDiagnostics.recordFromAnyActor("profile_fetch_remote_empty")
                return cachedProfile
            }

            guard let profile = profile(from: data, fallbackUser: user) else {
                OnboardingDebugDiagnostics.recordFromAnyActor("profile_fetch_remote_parse_failed")
                return cachedProfile
            }

            cache(profile)
            OnboardingDebugDiagnostics.recordFromAnyActor(
                "profile_fetch_remote_success hasCompleted=\(profile.hasCompletedOnboarding)"
            )
            return profile
        } catch {
            OnboardingDebugDiagnostics.recordFromAnyActor(
                "profile_fetch_remote_failed type=\(String(describing: type(of: error)))"
            )
            return cachedProfile
        }
    }

    func completeOnboarding(
        preferredName: String,
        experienceLevel: ExperienceLevel,
        focus: CoachingFocus,
        mode: ScenarioMode,
        roleTrack: RoleTrack
    ) async throws -> UserProfileRecord {
        OnboardingDebugDiagnostics.recordFromAnyActor("profile_save_start")
        let sanitizedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let user = Auth.auth().currentUser else {
            OnboardingDebugDiagnostics.recordFromAnyActor("profile_save_failed missing_auth_user")
            throw APIError.unauthenticated
        }

        guard !sanitizedName.isEmpty else {
            OnboardingDebugDiagnostics.recordFromAnyActor("profile_save_failed missing_preferred_name")
            throw UserProfileServiceError.missingPreferredName
        }

        let existingProfile = cachedProfile(for: user.uid)
        let localProfile = UserProfileRecord(
            uid: user.uid,
            email: user.email ?? existingProfile?.email,
            displayName: user.displayName ?? existingProfile?.displayName,
            preferredName: sanitizedName,
            locale: existingProfile?.locale ?? Locale.current.language.languageCode?.identifier ?? "en",
            planTier: existingProfile?.planTier ?? "free",
            onboardingGoalMode: mode,
            selectedRoleTrack: roleTrack,
            experienceLevel: experienceLevel,
            selfReportedFocus: focus,
            onboardingCompletedAt: existingProfile?.onboardingCompletedAt ?? Date(),
            streakCurrent: existingProfile?.streakCurrent ?? 0,
            streakBest: existingProfile?.streakBest ?? 0,
            lastPracticeDate: existingProfile?.lastPracticeDate
        )

        cache(localProfile)
        OnboardingDebugDiagnostics.recordFromAnyActor("profile_save_cached hasCompleted=\(localProfile.hasCompletedOnboarding)")
        Task {
            await syncProfileToRemote(localProfile, for: user)
        }
        OnboardingDebugDiagnostics.recordFromAnyActor("profile_save_end")
        return localProfile
    }

    func updateProfile(
        preferredName: String,
        experienceLevel: ExperienceLevel,
        focus: CoachingFocus,
        mode: ScenarioMode,
        roleTrack: RoleTrack
    ) async throws -> UserProfileRecord {
        try await completeOnboarding(
            preferredName: preferredName,
            experienceLevel: experienceLevel,
            focus: focus,
            mode: mode,
            roleTrack: roleTrack
        )
    }

    func refreshIdentityFields() async throws {
        guard let user = Auth.auth().currentUser else {
            return
        }

        if var cachedProfile = cachedProfile(for: user.uid) {
            cachedProfile = UserProfileRecord(
                uid: cachedProfile.uid,
                email: user.email ?? cachedProfile.email,
                displayName: user.displayName ?? cachedProfile.displayName,
                preferredName: cachedProfile.preferredName,
                locale: cachedProfile.locale,
                planTier: cachedProfile.planTier,
                onboardingGoalMode: cachedProfile.onboardingGoalMode,
                selectedRoleTrack: cachedProfile.selectedRoleTrack,
                experienceLevel: cachedProfile.experienceLevel,
                selfReportedFocus: cachedProfile.selfReportedFocus,
                onboardingCompletedAt: cachedProfile.onboardingCompletedAt,
                streakCurrent: cachedProfile.streakCurrent,
                streakBest: cachedProfile.streakBest,
                lastPracticeDate: cachedProfile.lastPracticeDate
            )
            cache(cachedProfile)
        }

        do {
            try await withTimeout(seconds: syncTimeout) {
                try await self.db.collection("users").document(user.uid).setData([
                    "email": user.email ?? NSNull(),
                    "displayName": user.displayName ?? NSNull(),
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            }
        } catch {
            // Identity is already held by Firebase Auth; Firestore sync can catch up later.
        }
    }

    private func profile(from data: [String: Any], fallbackUser user: User) -> UserProfileRecord? {
        let goalMode = ScenarioMode(rawValue: data["onboardingGoalMode"] as? String ?? "") ?? .workplace
        let roleTrack = RoleTrack(rawValue: data["selectedRoleTrack"] as? String ?? "") ?? .general
        let experienceLevel = ExperienceLevel(rawValue: data["experienceLevel"] as? String ?? "") ?? .zeroToOneYears
        let selfReportedFocus = CoachingFocus(rawValue: data["selfReportedFocus"] as? String ?? "") ?? .clarity
        let completedAt = (data["onboardingCompletedAt"] as? Timestamp)?.dateValue()
        let preferredName = (data["preferredName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = derivedPreferredName(for: user, existingName: nil)

        return UserProfileRecord(
            uid: user.uid,
            email: data["email"] as? String ?? user.email,
            displayName: data["displayName"] as? String ?? user.displayName,
            preferredName: preferredName?.isEmpty == false ? preferredName! : fallbackName,
            locale: data["locale"] as? String ?? "en",
            planTier: data["planTier"] as? String ?? "free",
            onboardingGoalMode: goalMode,
            selectedRoleTrack: roleTrack,
            experienceLevel: experienceLevel,
            selfReportedFocus: selfReportedFocus,
            onboardingCompletedAt: completedAt,
            streakCurrent: data["streakCurrent"] as? Int ?? 0,
            streakBest: data["streakBest"] as? Int ?? 0,
            lastPracticeDate: data["lastPracticeDate"] as? String
        )
    }

    private func syncProfileToRemote(_ localProfile: UserProfileRecord, for user: User) async {
        let ref = db.collection("users").document(user.uid)

        do {
            OnboardingDebugDiagnostics.recordFromAnyActor("profile_remote_sync_start")
            let existingSnapshot = try? await fetchRemoteSnapshot(for: user.uid)
            let current = existingSnapshot?.data() ?? [:]

            let payload: [String: Any] = [
                "uid": user.uid,
                "email": (user.email ?? localProfile.email) as Any,
                "displayName": (user.displayName ?? localProfile.displayName) as Any,
                "preferredName": localProfile.preferredName,
                "locale": localProfile.locale,
                "planTier": current["planTier"] as? String ?? localProfile.planTier,
                "onboardingGoalMode": localProfile.onboardingGoalMode.rawValue,
                "selectedRoleTrack": localProfile.selectedRoleTrack.rawValue,
                "experienceLevel": localProfile.experienceLevel.rawValue,
                "selfReportedFocus": localProfile.selfReportedFocus.rawValue,
                "onboardingCompletedAt": current["onboardingCompletedAt"] ?? localProfile.onboardingCompletedAt ?? Date(),
                "streakCurrent": current["streakCurrent"] as? Int ?? localProfile.streakCurrent,
                "streakBest": current["streakBest"] as? Int ?? localProfile.streakBest,
                "lastPracticeDate": current["lastPracticeDate"] ?? localProfile.lastPracticeDate ?? NSNull(),
                "createdAt": current["createdAt"] ?? FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            try await withTimeout(seconds: syncTimeout) {
                try await ref.setData(payload, merge: true)
            }

            if
                let refreshed = try? await withTimeout(seconds: syncTimeout, operation: {
                    try await ref.getDocument()
                }),
                let data = refreshed.data(),
                let remoteProfile = self.profile(from: data, fallbackUser: user)
            {
                cache(merged(remote: remoteProfile, cached: localProfile))
                OnboardingDebugDiagnostics.recordFromAnyActor(
                    "profile_remote_sync_end remoteCompleted=\(remoteProfile.hasCompletedOnboarding)"
                )
            }
        } catch {
            OnboardingDebugDiagnostics.recordFromAnyActor(
                "profile_remote_sync_failed type=\(String(describing: type(of: error)))"
            )
            // Keep the local profile as the source of truth until Firestore becomes reachable.
        }
    }

    private func refreshRemoteProfile(for user: User) async {
        do {
            OnboardingDebugDiagnostics.recordFromAnyActor("profile_refresh_remote_start")
            let cached = normalizedProfile(cachedProfile(for: user.uid), for: user)
            let snapshot = try await fetchRemoteSnapshot(for: user.uid)
            guard let data = snapshot.data(), let remoteProfile = profile(from: data, fallbackUser: user) else {
                OnboardingDebugDiagnostics.recordFromAnyActor("profile_refresh_remote_empty")
                return
            }
            let mergedProfile = merged(remote: remoteProfile, cached: cached)
            cache(mergedProfile)
            OnboardingDebugDiagnostics.recordFromAnyActor(
                "profile_refresh_remote_end remoteCompleted=\(remoteProfile.hasCompletedOnboarding) mergedCompleted=\(mergedProfile.hasCompletedOnboarding)"
            )
        } catch {
            OnboardingDebugDiagnostics.recordFromAnyActor(
                "profile_refresh_remote_failed type=\(String(describing: type(of: error)))"
            )
            // Keep the cached profile until Firestore becomes reachable.
        }
    }

    private func merged(remote: UserProfileRecord, cached: UserProfileRecord?) -> UserProfileRecord {
        guard let cached else { return remote }

        let shouldPreserveCompletedLocal = cached.hasCompletedOnboarding && !remote.hasCompletedOnboarding
        let preferredName = remote.hasMeaningfulProfile ? remote.preferredName : cached.preferredName

        return UserProfileRecord(
            uid: remote.uid,
            email: remote.email ?? cached.email,
            displayName: remote.displayName ?? cached.displayName,
            preferredName: preferredName,
            locale: remote.locale,
            planTier: remote.planTier,
            onboardingGoalMode: shouldPreserveCompletedLocal ? cached.onboardingGoalMode : remote.onboardingGoalMode,
            selectedRoleTrack: shouldPreserveCompletedLocal ? cached.selectedRoleTrack : remote.selectedRoleTrack,
            experienceLevel: shouldPreserveCompletedLocal ? cached.experienceLevel : remote.experienceLevel,
            selfReportedFocus: shouldPreserveCompletedLocal ? cached.selfReportedFocus : remote.selfReportedFocus,
            onboardingCompletedAt: shouldPreserveCompletedLocal ? cached.onboardingCompletedAt : remote.onboardingCompletedAt,
            streakCurrent: remote.streakCurrent,
            streakBest: max(remote.streakBest, cached.streakBest),
            lastPracticeDate: remote.lastPracticeDate ?? cached.lastPracticeDate
        )
    }

    private func derivedPreferredName(for user: User, existingName: String?) -> String {
        resolvePreferredName(
            existingName: existingName,
            displayName: user.displayName,
            email: user.email
        )
    }

    private func normalizedProfile(_ profile: UserProfileRecord?, for user: User) -> UserProfileRecord? {
        guard let profile else { return nil }

        let preferredName = derivedPreferredName(for: user, existingName: profile.preferredName)
        guard preferredName != profile.preferredName else { return profile }

        let normalized = UserProfileRecord(
            uid: profile.uid,
            email: profile.email,
            displayName: profile.displayName,
            preferredName: preferredName,
            locale: profile.locale,
            planTier: profile.planTier,
            onboardingGoalMode: profile.onboardingGoalMode,
            selectedRoleTrack: profile.selectedRoleTrack,
            experienceLevel: profile.experienceLevel,
            selfReportedFocus: profile.selfReportedFocus,
            onboardingCompletedAt: profile.onboardingCompletedAt,
            streakCurrent: profile.streakCurrent,
            streakBest: profile.streakBest,
            lastPracticeDate: profile.lastPracticeDate
        )
        cache(normalized)
        return normalized
    }

    private func fetchRemoteSnapshot(for uid: String) async throws -> DocumentSnapshot {
        try await withTimeout(seconds: syncTimeout) {
            try await self.db.collection("users").document(uid).getDocument()
        }
    }

    private func cache(_ profile: UserProfileRecord) {
        guard let data = try? encoder.encode(profile) else { return }
        defaults.set(data, forKey: cacheKey(for: profile.uid))
        OnboardingDebugDiagnostics.recordFromAnyActor(
            "profile_cache_write hasCompleted=\(profile.hasCompletedOnboarding) mode=\(profile.onboardingGoalMode.rawValue) role=\(profile.selectedRoleTrack.rawValue)"
        )
    }

    private func cachedProfile(for uid: String) -> UserProfileRecord? {
        guard let data = defaults.data(forKey: cacheKey(for: uid)) else {
            return nil
        }
        return try? decoder.decode(UserProfileRecord.self, from: data)
    }

    private func cacheKey(for uid: String) -> String {
        "clearify.profile.\(uid)"
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw CancellationError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
