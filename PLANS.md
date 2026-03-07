# PLANS.md

## Project
Clearify

## Objective
Make Clearify an airtight, production-grade iOS app by improving trust, product truth, core loop quality, progress usefulness, and release confidence without unnecessary scope expansion.

## Current status
- Phase: Hardening sprint
- Active sprint: Sprint 1
- Overall status: Audit complete — follow-up verification work required

---

## Operating rules
- `SPRINT.md` is the source of milestone truth
- `AGENTS.md` defines how Codex must operate
- Only one milestone should be executed at a time unless explicitly stated
- Every completed milestone must be logged below

## Rule for Codex
Always choose the first milestone in `SPRINT.md` whose status is not Complete in this file, unless explicitly instructed otherwise.

---

## Milestone status board

| ID | Title | Status | Notes |
|---|---|---|---|
| M1 | Brand consistency cleanup | Complete | User-visible brand leaks removed; internal legacy identifiers intentionally left in place |
| M2 | Misleading label and copy cleanup | Complete | Home labels now match current recommendation and search behavior |
| M3 | Dead control audit and fixes | Complete | Removed fake Home and Practice controls instead of inventing unsupported behavior |
| M4 | Paywall reason and message cleanup | Complete | Paywall now maps limit reasons to user copy and only promises session-limit removal |
| M5 | Persistence promise alignment | Complete | User-facing copy now distinguishes account-linked profile data from device-local saved answers and starred prompts |
| M6 | State ownership contract document | Complete | Added `docs/state-ownership-contract.md` covering source of truth, write authority, read priority, fallback, and user-facing promise for core entities |
| M7 | Favorites truth model cleanup | Complete | Extracted a dedicated local-only starred-prompt store, preserved existing IDs, and aligned library UI/copy to device-local behavior |
| M8 | Saved answers truth model cleanup | Complete | Extracted a dedicated local-only saved-answer store, preserved existing IDs, and aligned Progress and completion copy to the local-archive model |
| M9 | Home next-action clarity improvements | Complete | Home now centers one recommended next step, clearer session CTA choices, and lower-priority alternate prompt selection |
| M10 | Practice loop loading, feedback, and retry improvements | Partial | Implementation is present, but the live record → analyze → feedback → retry path was not end-to-end verified in this audit because the local emulator-backed backend was not running |
| M11 | Completion-state momentum improvements | Partial | Completion-state implementation is present, but it was not exercised through a successful live session in this audit |
| M12 | Progress usefulness and empty-state improvements | Complete | Progress now answers whether the user is improving, what is weak, and what to practice next using grounded existing signals |
| M13 | Backend endpoint coverage improvements | Complete | Added route-level tests for auth, validation, gating, fallback, and entitlement-sync behavior across the four critical endpoints |
| M14 | iOS flow and UI regression coverage | Partial | Deterministic unit coverage exists and passes, but the only UI regression test is stale/failing and does not currently protect the onboarding-to-dashboard path |

---

## Execution log

### Template
#### [Date] - [Milestone ID] - [Title]
- Status: Complete / Partial / Blocked
- Summary:
- Files changed:
- Tests/checks run:
- Acceptance criteria result:
- Risks / follow-ups:
- Next recommended milestone:

#### 2026-03-06 - M1 - Brand consistency cleanup
- Status: Complete
- Summary: Replaced remaining reachable `TalkTrack` branding in app metadata, onboarding copy, auth error copy, and profile fallback labels with `Clearify`. Updated the handover audit so it no longer reports a visible brand mismatch.
- Files changed:
  - `ios/Clearify/Sources/Services/AuthService.swift`
  - `ios/Clearify/Sources/Views/Onboarding/OnboardingView.swift`
  - `ios/Clearify/Sources/Views/RootView.swift`
  - `ios/Clearify/Resources/Info.plist`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `rg -n '\"[^\\\"]*TalkTrack[^\\\"]*\"' ios/Clearify`
  - `rg -n 'TalkTrack' ios/Clearify`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. No reachable production flow still shows `TalkTrack`; remaining occurrences are internal type names or local-only identifiers.
- Risks / follow-ups: Internal `TalkTrack` type names, local storage keys, and local archive folder naming remain as technical debt and should be handled separately if a safe migration is worth the churn.
- Next recommended milestone: M2 — Misleading label and copy cleanup

#### 2026-03-07 - M2 - Misleading label and copy cleanup
- Status: Complete
- Summary: Renamed the misleading Home `Favorites` section to a truthful recommendation/search label and corrected the Home search placeholder so it only claims scenario search. Updated the handover audit so it no longer lists these two issues as open.
- Files changed:
  - `ios/Clearify/Sources/Views/Home/HomeView.swift`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `rg -n 'Search scenarios or saved answers|TalkTrackSectionHeader\\(title: "Favorites"|The Home screen "Favorites" section is not actually favorites|Home search says it searches saved answers' ios/Clearify docs`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. Home labels now match the current behavior, and search language no longer claims saved-answer search.
- Risks / follow-ups: Persistence/account-backed copy remains to be audited in M5. True favorites semantics remain deferred to M7, and saved-answer persistence remains deferred to M8.
- Next recommended milestone: M3 — Dead control audit and fixes

#### 2026-03-07 - M3 - Dead control audit and fixes
- Status: Complete
- Summary: Removed the fake Home hamburger affordance and removed the no-op Practice utility buttons so the visible controls now map to real behavior only.
- Files changed:
  - `ios/Clearify/Sources/Views/Home/HomeView.swift`
  - `ios/Clearify/Sources/Views/Practice/PracticeSessionView.swift`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `rg -n 'line\\.3\\.horizontal|roundUtilityButton|xmark\\) \\{\\}|arrow\\.clockwise\\) \\{\\}|decorative/no-op' ios/Clearify/Sources docs`
  - `perl -0ne 'while(/Button\\s*\\{\\s*\\}/sg){print \"empty Button action found\\n\"; exit 1} END{exit 0}' $(rg --files ios/Clearify/Sources/Views ios/Clearify/Sources/ViewModels ios/Clearify/Sources/Views/Components)`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. The previously decorative or no-op controls on Home and Practice were removed, and the remaining visible controls in the touched flows have meaningful behavior.
- Risks / follow-ups: This milestone intentionally chose removal over inventing new menu or recording-reset behaviors. If future product work wants those affordances back, they should return with real behavior.
- Next recommended milestone: M4 — Paywall reason and message cleanup

#### 2026-03-07 - M4 - Paywall reason and message cleanup
- Status: Complete
- Summary: Replaced raw backend limit reasons in the paywall with calm user-facing copy, narrowed the Pro promise to session-limit removal only, and stopped purchase/restore errors from surfacing raw localized descriptions on the paywall.
- Files changed:
  - `ios/Clearify/Sources/Views/Paywall/PaywallView.swift`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `rg -n 'Limit reached:|Unlimited sessions, full history, and stronger trend tracking|error\\.localizedDescription|free_full_session_limit_reached|free_quick_drill_limit_reached' ios/Clearify/Sources/Views/Paywall docs/handover-audit.md -S`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. The paywall no longer renders raw backend reason codes, purchase and restore failures now use production-grade copy on this surface, and the Pro promise matches the currently implemented entitlement behavior.
- Risks / follow-ups: Backend reason codes still exist in the contract and telemetry can still log raw internal values; that is acceptable for this milestone because the user-facing UI no longer exposes them. Broader persistence and entitlement-truth cleanup remain for later milestones.
- Next recommended milestone: M5 — Persistence promise alignment

#### 2026-03-07 - M5 - Persistence promise alignment
- Status: Complete
- Summary: Corrected user-facing copy that implied account-backed sync for progress, saved answers, favorites, and general coaching data. The app now distinguishes account-linked profile/setup state from device-local saved answers and starred prompts without changing storage behavior.
- Files changed:
  - `ios/Clearify/Sources/Views/Onboarding/OnboardingView.swift`
  - `ios/Clearify/Sources/Views/Home/ScenarioLibraryView.swift`
  - `ios/Clearify/Sources/Views/Progress/ProgressViewScreen.swift`
  - `ios/Clearify/Sources/Views/RootView.swift`
  - `ios/Clearify/Sources/Views/Profile/AccountLinkView.swift`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `rg -n 'tied to your account|synced to your account|stay with you|stays attached to this account|Favorites stay one tap away|Keep your streak, saved answers, and coaching setup in one place' ios/Clearify/Sources docs -S`
  - `rg -n 'this device|coaching profile is connected to this account|coaching profile and plan stay linked to your account' ios/Clearify/Sources docs -S`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. The app no longer tells users that saved answers, favorites, or general coaching data automatically stay with the account when those items are still device-local or best-effort.
- Risks / follow-ups: This milestone intentionally did not change storage or sync behavior. Favorites and saved answers are still local-only by implementation and still need explicit source-of-truth cleanup in M7 and M8.
- Next recommended milestone: M6 — State ownership contract document

#### 2026-03-07 - M6 - State ownership contract document
- Status: Complete
- Summary: Added a state ownership contract document that defines where each core entity lives, who writes it, how reads fall back, what works cross-device, and what the UI is allowed to imply. The document matches the current implementation and explicitly separates backend-owned Firestore state from local-only device state.
- Files changed:
  - `docs/state-ownership-contract.md`
- Tests/checks run:
  - `test -f 'docs/state-ownership-contract.md' && echo 'exists'`
  - `rg -n '^\\| (User profile|Onboarding completion state|Sessions|Reps|Progress|Favorites|Saved answers|Entitlements|Scenario library|Local archive|Temporary uploaded audio) \\|' docs/state-ownership-contract.md`
  - `rg -n 'UserProfileService|LocalPracticeStore|progress_daily|entitlements|tmp/\\{uid\\}|scenarios.json|device-local only|remote first with local archive fallback|StoreKit transaction state mirrored into Firestore' docs/state-ownership-contract.md`
- Acceptance criteria result: Passed. The contract document exists, covers all required entities, and matches the current code paths and ownership boundaries.
- Risks / follow-ups: This milestone intentionally documented the current model without changing it. The next source-of-truth cleanup work remains in M7 and M8 for favorites and saved answers.
- Next recommended milestone: M7 — Favorites truth model cleanup

#### 2026-03-07 - M7 - Favorites truth model cleanup
- Status: Complete
- Summary: Clarified favorites as device-local starred prompts by extracting a dedicated local-only store, preserving the existing `UserDefaults` key for migration safety, and aligning the scenario-library UI and empty states to that model.
- Files changed:
  - `ios/Clearify/Sources/Services/FavoriteScenarioStore.swift`
  - `ios/Clearify/Sources/App/Dependencies.swift`
  - `ios/Clearify/Sources/Services/LocalPracticeStore.swift`
  - `ios/Clearify/Sources/ViewModels/ScenarioLibraryViewModel.swift`
  - `ios/Clearify/Sources/Views/Home/ScenarioLibraryView.swift`
  - `docs/state-ownership-contract.md`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `xcodegen generate`
  - `swiftc ios/Clearify/Sources/Services/FavoriteScenarioStore.swift /tmp/favorite_store_check.swift -o /tmp/favorite_store_check && /tmp/favorite_store_check`
  - `rg -n 'Favorites|favoriteScenarioIDs|favoritesOnly|toggleFavoriteScenario|isFavoriteScenario' ios/Clearify/Sources docs -S`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. Favorites are now explicitly device-local in code and UI, the storage boundary is clearer, and existing starred IDs are preserved.
- Risks / follow-ups: This milestone intentionally did not change saved-answer behavior. M8 should give saved answers the same explicit ownership cleanup.
- Next recommended milestone: M8 — Saved answers truth model cleanup

#### 2026-03-07 - M8 - Saved answers truth model cleanup
- Status: Complete
- Summary: Clarified saved answers as device-local local-archive state by extracting a dedicated saved-answer store, preserving the existing `UserDefaults` key for migration safety, and aligning Progress and completion copy to the local-archive model.
- Files changed:
  - `ios/Clearify/Sources/Services/SavedAnswerStore.swift`
  - `ios/Clearify/Sources/App/Dependencies.swift`
  - `ios/Clearify/Sources/Services/LocalPracticeStore.swift`
  - `ios/Clearify/Sources/ViewModels/ProgressViewModel.swift`
  - `ios/Clearify/Sources/ViewModels/PracticeSessionViewModel.swift`
  - `ios/Clearify/Sources/Views/Progress/ProgressViewScreen.swift`
  - `ios/Clearify/Sources/Views/Practice/PracticeSessionView.swift`
  - `docs/state-ownership-contract.md`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `xcodegen generate`
  - `swiftc ios/Clearify/Sources/Services/SavedAnswerStore.swift /tmp/saved_answer_store_check.swift -o /tmp/saved_answer_store_check && /tmp/saved_answer_store_check`
  - `rg -n 'savedAnswerIDs\\(|toggleSavedAnswer\\(|isSavedAnswer\\(|loadSavedSessions\\(' ios/Clearify/Sources docs -S`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. Saved answers are now explicitly device-local in code and UI, the storage boundary is clearer, and existing saved-answer IDs are preserved.
- Risks / follow-ups: This milestone intentionally did not change retention behavior for the local archive. Saved answers still depend on the archived session/audio remaining on this device.
- Next recommended milestone: M9 — Home next-action clarity improvements

#### 2026-03-07 - M9 - Home next-action clarity improvements
- Status: Complete
- Summary: Tightened the Home tab around one best-next prompt by making the recommendation the dominant action, clarifying the difference between full sessions and quick drills, demoting search into the alternate-prompt section, removing duplicate competition from the carousel, and replacing the loose bottom error with a focused fallback state.
- Files changed:
  - `ios/Clearify/Sources/ViewModels/HomeViewModel.swift`
  - `ios/Clearify/Sources/Views/Home/HomeView.swift`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `rg -n "Today's focus|See all|Start full session|Quick drill|Suggested for you|Matching scenarios|Search scenarios" ios/Clearify/Sources/Views/Home/HomeView.swift`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. Home now more clearly answers what the user should do next, session launch choices are easier to understand, and alternate prompt selection is still available without competing with the primary recommendation.
- Risks / follow-ups: This milestone intentionally did not change recording, loading, feedback, retry, or completion mechanics. Those remain for M10 and M11.
- Next recommended milestone: M10 — Practice loop loading, feedback, and retry improvements

#### 2026-03-07 - M10 - Practice loop loading, feedback, and retry improvements
- Status: Complete
- Summary: Tightened the core practice loop by adding explicit session-state messaging, clearer recording and analyzing guidance, calmer bounded error copy, a simplified feedback card focused on one main fix and one next try, and a dedicated retry action between reps.
- Files changed:
  - `ios/Clearify/Sources/ViewModels/PracticeSessionViewModel.swift`
  - `ios/Clearify/Sources/Views/Practice/PracticeSessionView.swift`
  - `ios/Clearify/Sources/Views/Components/FeedbackCardView.swift`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `rg -n "error\\.localizedDescription|Processing your answer\\.\\.\\.|Tap once to start\\. Tap again when the answer lands\\.|Primary improvement|Suggested structure|First sentence|Rambling check|Structure miss|Delivery signals|Tap to stop and analyze|Tap and talk" ios/Clearify/Sources/ViewModels/PracticeSessionViewModel.swift ios/Clearify/Sources/Views/Practice/PracticeSessionView.swift ios/Clearify/Sources/Views/Components/FeedbackCardView.swift -S`
  - `rg -n "Record your first answer|Take the next retry|Retry with one clear change|Start rep [0-9] of [0-9]|Main fix|Use this structure|Next try|Uploading your answer|Reviewing your answer" ios/Clearify/Sources/Views/Practice/PracticeSessionView.swift ios/Clearify/Sources/ViewModels/PracticeSessionViewModel.swift ios/Clearify/Sources/Views/Components/FeedbackCardView.swift docs/handover-audit.md -S`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. The practice loop now gives clearer guidance before recording, clearer state during upload and analysis, more scannable feedback, and an explicit retry path between reps.
- Risks / follow-ups: This milestone intentionally did not change completion-state structure beyond existing behavior. Momentum and next-action polish after session completion remain for M11.
- Next recommended milestone: M11 — Completion-state momentum improvements

#### 2026-03-07 - M11 - Completion-state momentum improvements
- Status: Complete
- Summary: Reframed the session completion state around one clear story: what changed in the answer, what the best next move is, and what alternate follow-up actions remain available. The completion card now recommends one primary action, keeps a secondary option explicit but lower-weight, and gives cleaner labels for saving the answer or returning home.
- Files changed:
  - `ios/Clearify/Sources/ViewModels/PracticeSessionViewModel.swift`
  - `ios/Clearify/Sources/Views/Practice/PracticeSessionView.swift`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `rg -n 'Text\\(\"Next step\"\\)|Button\\(\"Come back tomorrow\"\\)|actionButton\\(title: \"Related scenario\"|actionButton\\(title: \"Quick drill\"|Save best answer on this device' ios/Clearify/Sources/Views/Practice/PracticeSessionView.swift -S`
  - `rg -n 'What improved|What to carry into the next rep|Best next move|Or do this instead|Back to Home|Save this answer on this device|Practice a related prompt|Lock it in with one fast rep|Run this prompt once more' ios/Clearify/Sources/ViewModels/PracticeSessionViewModel.swift ios/Clearify/Sources/Views/Practice/PracticeSessionView.swift docs/handover-audit.md -S`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. The completion state now creates clearer momentum toward the next action by showing what changed, recommending one best follow-up move, and keeping supporting exits available without making them equally prominent.
- Risks / follow-ups: This milestone intentionally did not expand the completion action set or change session mechanics. Progress motivation and empty-state work remain for M12.
- Next recommended milestone: M12 — Progress usefulness and empty-state improvements

#### 2026-03-07 - M12 - Progress usefulness and empty-state improvements
- Status: Complete
- Summary: Strengthened the Progress tab so it now answers three questions directly: whether the user is improving, what their current weak spot is, and what to practice next. The screen now has more honest empty states, a grounded next-practice recommendation, clearer weekly-trend framing, calmer degraded-data messaging, and more readable recent-session summaries.
- Files changed:
  - `ios/Clearify/Sources/ViewModels/ProgressViewModel.swift`
  - `ios/Clearify/Sources/Views/Progress/ProgressViewScreen.swift`
  - `docs/handover-audit.md`
- Tests/checks run:
  - `rg -n 'func load\\(|await viewModel\\.load\\(|Practice next|No saved answers yet|No recent sessions yet|Using available progress data|What to look for first|What unlocks next|Moved up [0-9]|Building your first trend' ios/Clearify/Sources docs -S`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. Progress now creates clearer momentum toward another session, empty states are more useful, weak spots are easier to understand, and the recommendations remain grounded in existing data rather than fake analytics.
- Risks / follow-ups: This milestone intentionally did not add remote personalization, new analytics, or backend changes. Automated coverage for these behaviors remains for M14, and backend endpoint coverage remains for M13.
- Next recommended milestone: M13 — Backend endpoint coverage improvements

#### 2026-03-07 - M13 - Backend endpoint coverage improvements
- Status: Complete
- Summary: Added route-level regression coverage for the four critical backend endpoints by exporting the Express app for direct testing and exercising auth, validation, uid checks, gating passthrough, session analysis edge cases, cleanup fallback, completion failures, and entitlement sync behavior with mocked collaborators.
- Files changed:
  - `backend/functions/src/api.ts`
  - `backend/functions/test/api.test.ts`
  - `backend/functions/package.json`
  - `backend/functions/package-lock.json`
- Tests/checks run:
  - `cd backend/functions && npm test`
  - `cd backend/functions && npm run lint`
  - `cd backend/functions && npm run build`
- Acceptance criteria result: Passed. The critical backend flows now have meaningful regression protection for happy paths and key failure/edge cases without changing route behavior.
- Risks / follow-ups: This milestone intentionally used route tests with mocks instead of emulator/integration coverage. That keeps the suite fast and maintainable, but it does not replace end-to-end emulator or production smoke testing.
- Next recommended milestone: M14 — iOS flow and UI regression coverage

#### 2026-03-07 - M14 - iOS flow and UI regression coverage
- Status: Complete
- Summary: Added a dedicated iOS unit-test target and focused regression coverage for app bootstrap, onboarding state transitions, session launch gating, progress hydration fallback, and profile settings save behavior. Introduced only the small seams needed to make those flows testable without relying on brittle live auth/UI automation.
- Files changed:
  - `ios/Clearify/project.yml`
  - `ios/Clearify/Sources/App/AppState.swift`
  - `ios/Clearify/Sources/ViewModels/OnboardingViewModel.swift`
  - `ios/Clearify/Sources/ViewModels/ProgressViewModel.swift`
  - `ios/Clearify/Sources/ViewModels/PracticeSessionViewModel.swift`
  - `ios/Clearify/Sources/ViewModels/ProfileSettingsSubmission.swift`
  - `ios/Clearify/Sources/Views/Profile/ProfileSettingsView.swift`
  - `ios/Clearify/Tests/TestSupport.swift`
  - `ios/Clearify/Tests/AppStateTests.swift`
  - `ios/Clearify/Tests/OnboardingViewModelTests.swift`
  - `ios/Clearify/Tests/ProfileSettingsSubmissionTests.swift`
  - `ios/Clearify/Tests/ProgressViewModelTests.swift`
  - `ios/Clearify/Tests/PracticeSessionViewModelTests.swift`
- Tests/checks run:
  - `cd ios/Clearify && xcodegen generate`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClearifyTests test`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Passed. The highest-risk client flows now have focused automated regression protection, and the app still builds cleanly after the small testability refactors.
- Risks / follow-ups: This milestone intentionally favored deterministic unit coverage over brittle live UI automation. The pre-existing UI test target still depends on live auth/backend conditions and should be revisited later if full end-to-end simulator coverage is required.
- Next recommended milestone: None — all milestones in `SPRINT.md` are complete

#### 2026-03-07 - AUDIT - Full sprint verification pass
- Status: Partial
- Summary: Audited the repo against M1-M14, read milestone-related docs, ran backend lint/tests/build, ran iOS unit tests and build, attempted the existing iOS UI test, and inspected the main client/backend code paths. The repo is largely code-complete, but strict verification downgraded M10, M11, and M14 to Partial because the live emulator-backed practice loop was not runnable during the audit and the only UI regression test is stale/failing.
- Files changed:
  - `PLANS.md`
- Tests/checks run:
  - `cd backend/functions && npm test`
  - `cd backend/functions && npm run lint`
  - `cd backend/functions && npm run build`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClearifyTests test`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClearifyUITests test`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
  - targeted `rg` inspections for branding, misleading labels, raw paywall reasons, dead controls, persistence claims, and raw `localizedDescription` leaks
- Acceptance criteria result: Audit complete. M1-M9, M12, and M13 have strong supporting evidence; M10, M11, and M14 require follow-up verification or test repair.
- Risks / follow-ups:
  - `ios/Clearify/UITests/ClearifyUITests.swift` fails on the first onboarding assertion and still expects outdated dashboard copy (`Today's focus`), so it does not currently protect the onboarding-to-dashboard path.
  - Several user-facing surfaces still expose raw `error.localizedDescription` failures (`OnboardingView.swift`, `ProfileSettingsView.swift`, `AccountLinkView.swift`, `ScenarioLibraryViewModel.swift`).
  - Full record/analyze/retry verification requires the local Firebase emulators to be running.
- Next recommended milestone: M10 — Practice loop loading, feedback, and retry improvements (verification follow-up)

#### 2026-03-07 - FOLLOW-UP - UI regression harness repair
- Status: Partial
- Summary: Repaired the stale onboarding-to-dashboard UI harness by adding a deterministic UI-test reset hook, updating the test to current Home copy, and removing fixed-email reuse. The UI test now gets through intro onboarding correctly, but still stalls in account creation because the local Firebase emulator stack cannot run in this environment.
- Files changed:
  - `ios/Clearify/Sources/App/ClearifyApp.swift`
  - `ios/Clearify/Sources/App/UITestBootstrap.swift`
  - `ios/Clearify/UITests/ClearifyUITests.swift`
- Tests/checks run:
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClearifyUITests test`
  - `java -version`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Partial. The stale launch-state and stale-copy harness issues are fixed in code, but onboarding-to-dashboard UI verification is still blocked by missing local emulator prerequisites.
- Risks / follow-ups:
  - Do not treat M14 as fully verified until Java is installed, Firebase emulators are started, and the repaired UI test completes successfully.
  - The next verification pass should use the repaired UI harness rather than reworking it again.
- Next recommended milestone: M10-V — Live practice loop verification

#### 2026-03-07 - FOLLOW-UP - Local emulator environment verification
- Status: Partial
- Summary: Installed a local Java runtime with `brew install openjdk@21`, verified the repo can start the required Firebase emulator stack, and confirmed the local Functions health endpoint responds. Re-ran the repaired onboarding UI harness against the live local stack. The environment blocker is resolved, but onboarding still does not complete end-to-end under the live debug setup, so the full session, quick drill, and completion-state verification remain blocked behind a local auth/onboarding transition failure.
- Files changed:
  - `ios/Clearify/UITests/ClearifyUITests.swift`
  - `PLANS.md`
- Tests/checks run:
  - `java -version` (before install: failed; after install with Homebrew OpenJDK 21: succeeded)
  - `node -v`
  - `npm -v`
  - `npx firebase-tools --version`
  - `brew install openjdk@21`
  - `npx firebase-tools emulators:start --only auth,functions,firestore,storage`
  - `curl -s 'http://127.0.0.1:5001/clearify-5414d/us-central1/api/health'`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClearifyUITests test`
  - `curl -s -X POST 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key' ...`
- Acceptance criteria result: Partial. The local debug environment is now runnable, and onboarding intro -> account entry is verified. However, onboarding -> dashboard is still not proven because the app/test path does not complete account creation and profile handoff reliably under the live local stack. The full session live path, quick drill path, and completion state after a successful session remain unverified.
- Risks / follow-ups:
  - This is no longer a machine-dependency blocker. It is now either a client-side onboarding/auth transition bug or a remaining UI-harness interaction issue after account creation.
  - Direct Auth emulator signup succeeds, so the emulator stack itself is healthy.
  - The app-side outcome after tapping `Create account with email` is still not proven cleanly enough from automation alone, so the next pass should inspect that local onboarding/auth transition directly instead of assuming emulator failure.
  - Do not mark M10-V verified until onboarding reaches the dashboard and a real session can be started against the local stack.
- Next recommended milestone: M10-V — Live practice loop verification

---

## Blockers
- Local debug verification requirements are now confirmed and runnable on this machine:
  - Java runtime available
  - Firebase emulators for `Auth` (`127.0.0.1:9099`), `Firestore` (`127.0.0.1:8080`), `Storage` (`127.0.0.1:9199`), and `Functions` (`http://127.0.0.1:5001/clearify-5414d/us-central1/api`)
  - `OPENAI_API_KEY` exported when starting Functions so `analyzeRep` can run
- Remaining blocker: onboarding still does not complete end-to-end under the live local debug stack, so the app cannot yet be driven from onboarding -> dashboard -> full session / quick drill for real-session verification.
- The current evidence points to a client-side onboarding/auth transition issue or a remaining post-auth UI interaction issue, not a missing local runtime dependency.

---

## Decisions log

### Template
- Date:
- Decision:
- Reason:
- Impact:

- Date: 2026-03-07
- Decision: Regraded M10, M11, and M14 from Complete to Partial after the full-repo audit.
- Reason: The repo contains the intended implementation, but the current evidence does not fully satisfy strict verification. The live practice loop could not be exercised without the local emulator-backed backend, and the only UI regression test currently fails.
- Impact: The sprint is code-complete but not verification-complete. The next execution pass should reopen the earliest partial milestone rather than assuming Sprint 1 is fully closed.

- Date: 2026-03-06
- Decision: Leave internal `TalkTrack` type names, local storage keys, and local archive folder naming unchanged in M1.
- Reason: M1 is limited to user-visible brand consistency. Renaming local identifiers or archive paths would introduce migration risk without changing reachable UX.
- Impact: User-visible branding is now consistent as `Clearify`, while internal rename debt remains explicitly documented.

- Date: 2026-03-07
- Decision: Fix the misleading Home `Favorites` and search labels with copy changes only, rather than implementing true favorites or saved-answer search in M2.
- Reason: M2 is a label/copy milestone. Implementing behavior changes here would overlap M7 and M8 and create unnecessary scope expansion.
- Impact: Home is now truthful about current behavior, while favorites and saved-answer truth models remain explicit follow-up milestones.

- Date: 2026-03-07
- Decision: Remove dead control-looking affordances in Home and Practice rather than assigning them speculative behavior in M3.
- Reason: There is no implemented menu surface behind the Home icon, and the Practice utility buttons had no coherent low-risk behavior to attach without changing the recording/session model.
- Impact: The UI is now more trustworthy because visible controls only remain where meaningful actions exist.

- Date: 2026-03-07
- Decision: Fix paywall trust issues in M4 with client-side copy and error mapping only, without changing entitlement scope or backend reason contracts.
- Reason: The milestone is about reason/message cleanup. Expanding Pro unlock behavior or refactoring backend contracts would add unnecessary scope and risk.
- Impact: The paywall is now truthful and calm for users, while the existing backend reason codes remain available internally for gating and analytics.

- Date: 2026-03-07
- Decision: Fix persistence-promise mismatches in M5 with copy alignment only, without changing sync/storage behavior.
- Reason: The milestone is about truthfulness, not data-model expansion. Changing persistence behavior here would overlap later milestones and introduce avoidable risk.
- Impact: User-facing surfaces now describe account-linked profile/setup state and device-local saved answers/starred prompts more accurately, while the underlying storage model remains unchanged for later cleanup.

- Date: 2026-03-07
- Decision: Use M6 to document the current state-ownership model exactly as implemented, without refactoring storage or ownership behavior.
- Reason: The sprint milestone requires a source-of-truth contract document. Refactoring data ownership here would overlap later milestones and create unnecessary risk before the model is explicitly captured.
- Impact: Engineers now have a single file that defines current ownership and fallback behavior, and later milestones can change the model intentionally instead of by implication.

- Date: 2026-03-07
- Decision: Treat favorites as device-local starred prompts in M7 and preserve the legacy `UserDefaults` key instead of migrating to a new store key.
- Reason: The current architecture already stores favorites locally. Preserving the existing key keeps existing user data intact while making the ownership boundary explicit in code and UI.
- Impact: Favorites are now clearer for both users and engineers without breaking existing starred prompts.

- Date: 2026-03-07
- Decision: Treat saved answers as device-local local-archive state in M8 and preserve the legacy `UserDefaults` key instead of migrating to a new store key.
- Reason: The current architecture already stores saved-answer IDs locally and resolves them through the device archive. Preserving the existing key keeps current saved answers intact while making the ownership boundary explicit in code and UI.
- Impact: Saved answers are now clearer for both users and engineers without breaking existing saved-answer state.

- Date: 2026-03-07
- Decision: Improve Home clarity in M9 by tightening hierarchy and launch copy only, without changing session mechanics or adding new product surfaces.
- Reason: The milestone is about making Home answer “what should I do now?” clearly. Changing recording, feedback, or completion behavior here would overlap later milestones and blur sprint boundaries.
- Impact: The Home tab now emphasizes one recommended next action while preserving the existing session model for M10 and M11.

- Date: 2026-03-07
- Decision: Tighten the practice loop in M10 by improving state messaging, feedback hierarchy, and retry clarity without changing backend contracts or completion-state scope.
- Reason: The milestone is about making record → analyze → feedback → retry clearer and more actionable. Expanding into completion redesign or backend behavior changes would overlap M11 and later milestones.
- Impact: The practice sheet now better explains what is happening and what to do next after each rep, while the session model and completion flow remain stable.

- Date: 2026-03-07
- Decision: Improve completion momentum in M11 by restructuring the existing completion card around one recommended next action, rather than adding new post-session behaviors.
- Reason: The milestone is about making completion feel directional, not about expanding the action set or changing session mechanics. Reordering and clarifying the existing actions is the lowest-risk way to create momentum.
- Impact: The end of a session now tells the user what changed and which next move is best, while preserving the same underlying actions and backend behavior.

- Date: 2026-03-07
- Decision: Improve Progress usefulness in M12 using only existing signals from snapshots, recent sessions, saved answers, and scenario ranking.
- Reason: The milestone is about making Progress behaviorally useful without inventing fake sophistication. Reusing the current data model is the safest way to improve actionability while keeping the product honest.
- Impact: Progress now highlights trend, weak spot, recent win, and next practice more clearly, without overstating what the underlying system knows.

- Date: 2026-03-07
- Decision: Cover M13 with direct route tests against the exported Express app and mocked collaborators instead of Firebase emulators.
- Reason: The milestone is about regression protection for endpoint behavior. Route-level tests cover auth, validation, gating, fallback, and write contracts precisely while staying fast, deterministic, and low-maintenance.
- Impact: Critical backend routes now have strong automated coverage, while full emulator/integration testing remains a separate future concern.

- Date: 2026-03-07
- Decision: Cover M14 with deterministic unit tests and narrow test seams instead of expanding brittle live UI automation.
- Reason: The highest-risk client logic lives in bootstrap, onboarding, session-launch gating, progress fallback, and profile save behavior. Small dependency seams make those flows testable without requiring Firebase/Auth emulator state or fragile UI timing.
- Impact: The iOS client now has meaningful regression protection for core flow logic, while full simulator/device end-to-end coverage remains a separate future concern.

- Date: 2026-03-07
- Decision: Repair the stale UI regression harness with deterministic app-state reset and current-copy assertions before attempting broader live verification.
- Reason: The audit showed the only UI regression test was failing for stale reasons before it even reached the real onboarding/account path. Fixing the harness first is the narrowest way to distinguish harness bugs from actual debug-environment or product blockers.
- Impact: The UI test now advances through intro onboarding reliably, and the remaining failure is narrowed to the local emulator-backed account creation path rather than stale launch state or outdated copy.

- Date: 2026-03-07
- Decision: Install OpenJDK 21 locally and treat the remaining live-debug verification failure as a product/UI-path blocker rather than an environment blocker.
- Reason: The audit follow-up required proving whether the local Firebase stack could run. After installing Java, the emulators started successfully and the Functions health endpoint responded. Direct signup against the Auth emulator also succeeded, which means the remaining failure is no longer caused by missing local runtime dependencies.
- Impact: The next follow-up should focus on the app's local onboarding/auth transition path so the dashboard and real session loop can be verified end-to-end.

---

## Current repo truths

### Branding
- Product name: Clearify

### Persistence
- Profile: Firestore-backed with local cache fallback
- Sessions: backend-owned remote model with local archive fallback
- Reps: backend-owned
- Favorites: device-local starred prompts
- Saved answers: device-local local-archive state
- Full ownership contract: `docs/state-ownership-contract.md`

### Entitlements
- StoreKit + backend sync
- Pro messaging must match actual unlock behavior only

### Practice modes
- Full session = 3 reps
- Quick drill = 1 rep

### Current quality focus
- Trust
- Truthful product behavior
- Clear main loop
- Useful progress
- Release confidence

---

## Next up
- M10-V — Live practice loop verification
