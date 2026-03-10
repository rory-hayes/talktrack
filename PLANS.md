# PLANS.md

## Project
Clearify

## Objective
Make Clearify an airtight, production-grade iOS app by improving trust, product truth, core loop quality, progress usefulness, and release confidence without unnecessary scope expansion.

## Current status
- Phase: Hardening sprint
- Active sprint: Sprint 1
- Overall status: Audit hardening pass implemented — backend session/quota and emulator-backed analyze are verified live, the flaky onboarding profile-footer transition is now explicitly parked for later investigation, and shell-level UI verification is proceeding through a new authenticated dashboard bootstrap path

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
| M10 | Practice loop loading, feedback, and retry improvements | Partial | Live backend verification now covers full/quick session starts, fair quota consumption on completion, and emulator-backed analyze; the onboarding profile-footer flake is parked, authenticated dashboard/session-entry verification now passes, and the remaining gap is app-side record/analyze/retry/completion/recommendation-refresh verification from the shell |
| M11 | Completion-state momentum improvements | Partial | Completion-state implementation is present, but it was not exercised through a successful live session in this audit |
| M12 | Progress usefulness and empty-state improvements | Complete | Progress now answers whether the user is improving, what is weak, and what to practice next using grounded existing signals |
| M13 | Backend endpoint coverage improvements | Complete | Added route-level tests for auth, validation, gating, fallback, and entitlement-sync behavior across the four critical endpoints |
| M14 | iOS flow and UI regression coverage | Partial | Deterministic unit coverage exists and passes; the onboarding profile-footer regression is parked for later investigation, a reliable authenticated dashboard bootstrap now covers shell launch plus full/quick session entry, and broader live practice-loop UI coverage still remains open |

---

## Execution log

#### 2026-03-10 - M10-V shell pass - Authenticated dashboard bootstrap and session-entry verification
- Status: Partial
- Summary: Explicitly parked the unstable authenticated onboarding profile-footer investigation for this pass and switched forward verification onto a new UITest-only authenticated/onboarding-complete bootstrap path. `UITestBootstrap` can now sign into the local Auth emulator with a deterministic audit account, seed an onboarding-complete profile, and let `RootView` hydrate directly into the main shell without replaying the flaky onboarding footer path. With that entry path in place, I re-ran shell-level UI verification and confirmed the dashboard loads from an already-authenticated state. The next downstream issue turned out to be narrower than onboarding and test-facing rather than a product-flow break: the Home session CTAs were built from stacked title/subtitle labels, so the existing UITest queries for `"Start 3-rep practice"` and `"Take 1 quick drill"` were brittle exact-label matches. I added explicit accessibility identifiers to the two Home session-start controls and updated the UITests to target those controls directly. Serial reruns now pass for authenticated dashboard launch, full-session entry, and quick-drill entry.
- Files changed:
  - `ios/Clearify/Sources/App/UITestBootstrap.swift`
  - `ios/Clearify/Sources/Views/RootView.swift`
  - `ios/Clearify/Sources/Views/Home/HomeView.swift`
  - `ios/Clearify/UITests/ClearifyUITests.swift`
  - `PLANS.md`
- Tests/checks run:
  - Re-read `AGENTS.md`, `PLANS.md`, `SPRINT.md`, and the latest M10-V / onboarding-blocker entries before implementation
  - Confirmed local backend readiness with `curl -sf http://127.0.0.1:5001/clearify-5414d/us-central1/api/health`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-auth-bootstrap-dd test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testAuthenticatedBootstrapLaunchesToDashboard -only-testing:ClearifyUITests/ClearifyUITests/testFullSessionStartsFromDashboard -only-testing:ClearifyUITests/ClearifyUITests/testQuickDrillStartsFromDashboard`
  - Inspected the intermediate failing xcresult (`/tmp/clearify-auth-bootstrap-dd/Logs/Test/Test-Clearify-2026.03.10_20-57-19-+0000.xcresult`) to confirm the dashboard was loading and the remaining miss was the CTA query target, then reran the same focused UITest set to green after the accessibility-identifier fix (`/tmp/clearify-auth-bootstrap-dd/Logs/Test/Test-Clearify-2026.03.10_21-01-11-+0000.xcresult`)
- Acceptance criteria result: Partial. This pass now provides a reliable already-authenticated, onboarding-complete entry path and verifies that the app launches into dashboard, starts a full session from dashboard, and starts a quick drill from dashboard without relying on the parked onboarding footer flow. The broader app-side record/upload/analyze/feedback, retry progression, completion state, and recommendation refresh are still not re-verified end to end from the shell in this pass.
- Risks / follow-ups:
  - Parked / deferred blocker: the broader onboarding profile-footer dispatch issue remains unresolved and should stay out of scope until shell-level hardening work is exhausted or a separate focused investigation is explicitly resumed.
  - The new authenticated bootstrap is intentionally UITest-only and guarded to local-backend/emulator usage; it should not be treated as production behavior.
  - Full practice-loop UI verification still lacks a deterministic app-side recorder/analyze harness from the authenticated shell. Backend analyze/quota behavior remains verified from the prior live emulator-backed work, but the UI path through recording, feedback, retry, completion, and post-completion recommendation refresh is still open.
- Next recommended milestone: Continue M10-V from the authenticated dashboard shell by adding or using the narrowest deterministic test/debug seam available for the app-side practice loop, then verify record/analyze/feedback, retry progression, completion UI, and recommendation refresh without returning to the parked onboarding footer investigation.

#### 2026-03-10 - M10-V targeted app pass - Profile footer dispatch investigation
- Status: Partial
- Summary: Investigated the app-side dispatch miss for `onboarding.footer.profile` in the broader onboarding-to-dashboard flow without removing the ordered onboarding debug instrumentation or spending the pass on generic UITest timing. The strongest runtime evidence is still in the failing profile-step hierarchies: the footer button remains `exists=true` and `hittable=true`, but the accessibility hierarchy shows the profile footer frame overlapping the lower career-stage rows (`2-4 years` at `{{40.0, 679.7}, {322.0, 90.0}}`, `onboarding.footer.profile` at `{{40.0, 719.7}, {322.0, 60.0}}`, `5-7 years` at `{{40.0, 783.7}, {322.0, 90.0}}`), and the debug descriptions for the footer query still include lingering `Not Now` / `Save` descendants from the post-signup password sheet. That keeps pointing at app-side hit interception or out-of-bounds hit-testing in the footer band, not backend/auth. I tried only narrow app-side interaction/layout changes in `OnboardingView`: restored the authenticated setup footer to a bottom `ZStack` with reserved footer space, clipped the setup `ScrollView`, added debounced ordered footer diagnostics plus explicit high-priority tap handling, and then expanded the authenticated footer interaction area so the fixed setup footer can be driven by a dedicated transparent hit proxy layered above the visual footer. The results are still mixed. A clean broader rerun did reach dashboard and recorded `[43] footer_tap_enter step=profile`, `[47] advance_authenticated_progress_enter reason=footer_profile_continue ... resolved=focus`, and `[52] visible_step_changed to=focus` before failing later at the next dashboard entry point (`Missing button: "Start 3-rep practice" Button`). But two subsequent clean serial reruns regressed back to the original app bug: both failed at `Expected focus step`, both reported `profileFooter.exists=true`, `profileFooter.hittable=true`, `focusFooter.exists=false`, and neither recorded a post-tap `footer_tap_enter step=profile`. A few additional runs were discarded because unrelated `xcodebuild` jobs on this machine kept starting mid-pass and polluted the verification environment. The blocker is narrower now, but the broader flow is still not stable enough to mark the footer dispatch fixed.
- Files changed:
  - `ios/Clearify/Sources/Views/Onboarding/OnboardingView.swift`
  - `PLANS.md`
- Tests/checks run:
  - Re-read `AGENTS.md`, `PLANS.md`, `SPRINT.md`, and compared the latest fixed-footer stabilization entry before code changes
  - Inspected `ios/Clearify/Sources/Views/Onboarding/OnboardingView.swift`, `ios/Clearify/Sources/Views/Components/TalkTrackDesignSystem.swift`, `ios/Clearify/Sources/App/OnboardingDebugDiagnostics.swift`, `ios/Clearify/Sources/ViewModels/OnboardingViewModel.swift`, `ios/Clearify/Sources/App/AppState.swift`, `ios/Clearify/Sources/Views/RootView.swift`, and `ios/Clearify/UITests/ClearifyUITests.swift`
  - Exported and compared failure attachments from serial broader-flow runs, including app UI hierarchies and footer debug descriptions
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-dispatch-dd test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testFullSessionStartsFromDashboard` clean rerun: 1 pass-through-profile / 1 fail-at-dashboard-entry (`tmp-appdispatch-fullsession-8.xcresult`)
  - The same command rerun serially two more clean times: 0 pass-through-profile / 2 fail-at-profile (`tmp-appdispatch-fullsession-9.xcresult`, `tmp-appdispatch-fullsession-10.xcresult`)
  - Additional broader reruns (`tmp-appdispatch-fullsession-6.xcresult`, `tmp-appdispatch-fullsession-7.xcresult`, `tmp-appdispatch-fullsession-11.xcresult`) were discarded from product evidence because repeated unrelated `xcodebuild` activity on this machine made the environment non-isolated again before trusted result capture
- Acceptance criteria result: Partial. The app-side investigation did move the blocker once and confirmed the exact next downstream failure after dashboard entry (`Start 3-rep practice` missing), but the broader onboarding-to-dashboard flow still does not dispatch `onboarding.footer.profile` reliably enough across repeated serial reruns to call the profile footer fixed.
- Risks / follow-ups:
  - App bug remains: broader-flow profile dispatch is still flaky. The ordered debug state proves the app sometimes never enters `handleFooterTap()` even though XCTest taps a hittable footer.
  - The latest retained fix adds a dedicated transparent footer hit proxy above the visual setup footer. That change is coherent and narrowly scoped, but it was not fully re-verified under a consistently isolated machine state because unrelated local `xcodebuild` jobs kept restarting mid-pass.
  - The exact next downstream blocker, once profile dispatch clears, is in dashboard/session entry: `testFullSessionStartsFromDashboard` reached dashboard and then failed at `Missing button: "Start 3-rep practice" Button`.
  - Required follow-up verification is still outstanding after the final retained footer-proxy change: rerun `testOnboardingCompletesOnceAndReturnsToDashboard` serially multiple times and rerun `testFullSessionStartsFromDashboard` serially multiple times on a machine state without competing `xcodebuild` jobs.
- Next recommended milestone: Finish stabilizing the app-side footer dispatch for the broader onboarding profile step in an actually isolated serial UI-test environment, then re-verify onboarding and continue through the dashboard session-entry blocker.

#### 2026-03-09 - M10-V stabilization pass - Onboarding fixed-footer verification and downstream dashboard entry
- Status: Partial
- Summary: Ran a final narrow stabilization pass against the onboarding fixed-footer interaction without redesigning onboarding or removing the ordered debug instrumentation. The only retained code change was in the UI-test harness: after account creation the test now dismisses the simulator's `Not Now` password prompt from either the app or SpringBoard, the fixed profile/focus footer buttons no longer trigger swipe-based scroll recovery, and the failure path now prints the ordered onboarding debug state directly into the `xcodebuild` log so crash-style runs still preserve the event sequence. With those harness changes in place, the isolated onboarding regression is now stable in serial runs: `testOnboardingCompletesOnceAndReturnsToDashboard` passed 3 out of 3 times, and every passing run logged both `footer_tap_enter step=profile` and `advance_authenticated_progress_enter reason=footer_profile_continue` before reaching dashboard and relaunching back into dashboard. However, the next downstream dashboard-entry test is still blocked by an app-side interaction defect in the same profile footer path: `testFullSessionStartsFromDashboard` failed 2 out of 2 times at `Expected focus step`, and the printed ordered debug state in both failures stopped at `restore_authenticated_progress_result ... visibleStep=profile authStep=profile` with `profileFooter.exists=true`, `profileFooter.hittable=true`, `focusFooter.exists=false`, and no post-tap `footer_tap_enter step=profile`. That means the remaining blocker is not the old footer-overlap layout bug and not the UITest swipe recovery path; it is still an app-side footer-dispatch miss that prevents the broader flow from reaching dashboard/session entry reliably enough to verify the next shell CTA.
- Files changed:
  - `ios/Clearify/UITests/ClearifyUITests.swift`
  - `PLANS.md`
- Tests/checks run:
  - Restarted local Firebase `auth`, `functions`, `firestore`, and `storage` emulators and confirmed readiness before UI reruns
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-stab test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard` run serially 3 times
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-stab test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testFullSessionStartsFromDashboard` run serially 2 times
  - `xcrun simctl shutdown all` before the downstream confirmation reruns to clear stale simulator state
- Acceptance criteria result: Partial. The remaining serial UITest flake caused by the post-signup system prompt and swipe recovery noise is reduced enough that the standalone onboarding regression now passes repeatedly with the expected ordered footer events. Onboarding is stable enough in isolation to keep the fixed-footer layout and current instrumentation, but it is not yet stable enough to unblock the broader dashboard/session-entry verification milestone because the downstream full-session test still reproduces an app-side profile-footer tap-dispatch miss before dashboard entry.
- Risks / follow-ups:
  - App bug: in the broader onboarding-to-dashboard path, a hittable `onboarding.footer.profile` button can still fail to dispatch `handleFooterTap()`. The ordered debug log proves the failure happens before validation or `advanceAuthenticatedProgress`, because no post-tap `footer_tap_enter step=profile` is recorded.
  - UITest timing issue addressed: the retained harness change now dismisses `Not Now` from SpringBoard as well as the app and avoids perturbing the fixed footer with swipe recovery.
  - Downstream UI issue still blocked: no reproducible post-dashboard session-entry blocker was reached in this pass because `testFullSessionStartsFromDashboard` never got past the profile step in the confirmed reruns.
- Next recommended milestone: Continue app-side hit-testing investigation on the authenticated profile footer in the broader onboarding/dashboard flow, using the retained ordered debug instrumentation as the source of truth; only after that path passes in `testFullSessionStartsFromDashboard` should the next downstream dashboard/session-entry blocker be classified.

#### 2026-03-07 - M10-V rerun - Full live practice loop verification after onboarding/analyze fixes
- Status: Partial
- Summary: Reran live local verification after the onboarding email-auth fix and emulator-backed analyze fix. Environment readiness is now solid: the local `auth`, `functions`, `firestore`, and `storage` emulators were running, `/health` responded, and `OPENAI_API_KEY` presence for the functions runtime was confirmed by a successful live `/analyzeRep` call that returned transcript plus structured feedback. The standalone onboarding UI regression on an isolated `iPhone 17 Pro` simulator passed and reached the dashboard. Live backend verification also reconfirmed fair quota behavior: abandoned full and quick starts did not consume quota, a completed quick drill blocked the next quick drill with `free_quick_drill_limit_reached`, and a completed full session reduced `remainingFullSessionsThisWeek` from `3` to `2`. However, the broader live UI verification is still blocked because onboarding progression is not stable across related UI flows: the very next dashboard-entry UI test (`testFullSessionStartsFromDashboard`) failed at the profile-to-focus transition with `Expected focus step`, which means the app cannot yet be treated as reliably onboarding into the shell before practice starts. Because of that instability, the app-side full-session start, quick-drill start, record/upload/analyze/feedback, retry progression, completion UI, and recommendation refresh after completion are still not verified end to end through the live app.
- Files changed:
  - `PLANS.md`
- Tests/checks run:
  - Confirmed local emulator readiness with `curl http://127.0.0.1:5001/clearify-5414d/us-central1/api/health`
  - Confirmed functions-runtime `OPENAI_API_KEY` indirectly via successful live `/analyzeRep` response
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-m10v-rerun-onboarding.xcresult`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
  - Repeated `xcodebuild` UI and unit-test commands for session-entry and onboarding/app-state checks; several were cancelled by DerivedData build-database lock collisions after I launched multiple Xcode jobs in parallel
  - Live backend verification script covering abandoned starts, quick analyze + complete, quick-drill limit enforcement, seeded full-session completion, and full-session quota decrement after completion
  - Simulator screenshots during stalled UI runs to distinguish harness delay from app-state failures
- Acceptance criteria result: Partial. Verified with concrete evidence: local emulator stack is ready; the functions runtime can analyze uploaded audio end to end; abandoned session starts do not consume quota; quick drills and full sessions consume quota on completion; a standalone onboarding run can reach dashboard. Not verified: stable onboarding into the app shell across related UI flows; app-side full-session start; app-side quick-drill start; record/upload/analyze/feedback path through the UI; retry progression UI; successful completion UI; recommendation refresh after completion in the live app.
- Risks / follow-ups: The main remaining blocker is a product bug, not environment setup: onboarding profile-to-focus/dashboard transition is still flaky or state-dependent in the live UI flow. A separate harness issue also showed up during this rerun: launching multiple `xcodebuild` jobs in parallel against the same DerivedData produced build-database lock failures, so those cancelled runs are not product evidence either way. The backend/emulator path is no longer the blocker.
- Next recommended milestone: Return to the onboarding profile-to-focus/dashboard transition and make that path stable under repeated UI runs, then rerun M10-V from the live app shell through practice, retry, completion, and recommendation refresh.

#### 2026-03-07 - M10-V follow-up - Emulator-backed analyze path
- Status: Complete
- Summary: Investigated the local `/analyzeRep` failure and confirmed the analyze route itself was intact; the failure came from backend Firebase Admin storage bootstrap in emulator mode. `firebase-admin` was being initialized without a reliable default bucket, so `storage.bucket()` could not consistently resolve the uploaded audio object under the local emulator stack even when `OPENAI_API_KEY` was present. Added a narrow bootstrap resolver that prefers explicit bucket configuration, reads `FIREBASE_CONFIG` when available, and only derives a default `${projectId}.appspot.com` bucket while running against Firebase emulators. Live verification now succeeds end to end for the backend analyze path: a fresh Auth emulator user started a session, a valid `.m4a` recording was uploaded into the Storage emulator, `/analyzeRep` returned transcript plus structured feedback, Firestore stored the rep, and the temporary audio object was deleted.
- Files changed:
  - `backend/functions/src/db.ts`
  - `backend/functions/src/firebaseBootstrap.ts`
  - `backend/functions/test/firebaseBootstrap.test.ts`
- Tests/checks run:
  - `cd backend/functions && npm run lint`
  - `cd backend/functions && npm test`
  - `cd backend/functions && npm run build`
  - Restarted `auth`, `functions`, `firestore`, and `storage` emulators with `OPENAI_API_KEY` available to the functions runtime
  - Generated a known-good local `.m4a` sample and verified direct OpenAI transcription acceptance
  - Live emulator-backed `/analyzeRep` verification: emulator signup, `/startSession`, Storage-emulator upload, `/analyzeRep`
  - Firestore/Storage emulator inspection after analyze to verify rep persistence and temp-audio cleanup
- Acceptance criteria result: Passed for this targeted fix. The emulator-backed analyze path can now read uploaded audio from Storage emulator, transcribe it, generate feedback, persist the rep, and clean up temp audio. Production bootstrap behavior remains explicit-first; the new derived bucket fallback only activates in emulator environments.
- Risks / follow-ups: The remaining blocker for full M10-V completion is on the iOS side: onboarding progression still fails at the profile-to-focus/dashboard transition, so the full live UI practice loop has not yet been re-verified from the app shell. The bucket fallback assumes the default Firebase Storage bucket naming convention `${projectId}.appspot.com` in emulator mode, which matches the current project setup and was verified live here.
- Next recommended milestone: Fix the onboarding profile-to-focus/dashboard transition, then rerun M10-V from dashboard through analyze, retry, completion, and recommendation refresh.

### Template
#### [Date] - [Milestone ID] - [Title]
- Status: Complete / Partial / Blocked
- Summary:
- Files changed:
- Tests/checks run:
- Acceptance criteria result:
- Risks / follow-ups:
- Next recommended milestone:

#### 2026-03-07 - M10-V - Live practice loop verification
- Status: Partial
- Summary: Verified the local debug stack against the live app/backend path as far as the current environment allowed. The app is correctly pointed at the local Firebase stack, `npx firebase-tools` plus Homebrew OpenJDK 21 were sufficient to start `auth`, `functions`, `firestore`, and `storage`, and the local `/health` endpoint responded successfully. The repaired onboarding UI harness still fails in the same place under live emulators: after tapping `Create account with email`, the app remains on the account screen and never produces a signed-in user or advances to the profile step. On the backend side, live session start and quota behavior were verified with real emulator auth tokens; abandoned full and quick starts did not consume quota, completed quick drills immediately hit the daily quick-drill limit, and a tiny backend transaction-ordering fix was required to make full-session completion succeed and decrement remaining weekly full sessions from `3` to `2`. The analyze/feedback path remains blocked in local verification because the backend requires `OPENAI_API_KEY`, which is not configured in this environment.
- Files changed:
  - `backend/functions/src/sessionService.ts`
  - `ios/Clearify/UITests/ClearifyUITests.swift`
- Tests/checks run:
  - `test -n "$OPENAI_API_KEY" && echo OPENAI_API_KEY_PRESENT || echo OPENAI_API_KEY_MISSING`
  - `npx firebase-tools --version`
  - `/opt/homebrew/opt/openjdk@21/bin/java -version`
  - `export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"; export JAVA_HOME="/opt/homebrew/opt/openjdk@21"; npx firebase-tools emulators:start --only auth,functions,firestore,storage`
  - `curl http://127.0.0.1:5001/clearify-5414d/us-central1/api/health`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-m10v-ui-2.xcresult`
  - `xcrun xcresulttool export object --legacy --path /Users/rory/Documents/Clarify AI/tmp-m10v-ui-2.xcresult --id <onboarding attachment id> --type file --output-path /Users/rory/Documents/Clarify AI/tmp-onboarding-stuck.txt`
  - Live emulator-auth session start / completion probes against `/startSession`, `/completeSession`, and `/analyzeRep`
  - `cd backend/functions && npm run lint`
  - `cd backend/functions && npm test`
  - `cd backend/functions && npm run build`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Partial. Environment readiness was recovered and the live backend session/quota path is now verified. Concrete evidence shows: `/health` is live; abandoned starts do not consume quota; completed quick drills consume quota at completion; completed full sessions now consume quota at completion after the transaction fix. The following acceptance criteria remain unverified or blocked: onboarding to dashboard through the live app fails in the email account path, so the app-side full-session start, quick-drill start, retry progression, completion UI, and recommendation refresh after completion could not be exercised; analyze/feedback could not succeed because `OPENAI_API_KEY` is missing, and direct backend invocation confirms that exact external dependency blocker.
- Risks / follow-ups: The onboarding failure is now classified as a product bug in the local email-auth transition path, not an emulator setup issue. The captured accessibility tree shows the app still on `Create your account` with `Create your account to continue.` after the create-account tap, and a timestamp-range check against the Auth emulator did not find the expected account, which suggests the sign-up did not complete. The analyze/feedback block is an external dependency issue until a valid `OPENAI_API_KEY` is configured or a deliberate local analysis stub is introduced.
- Next recommended milestone: Fix the local onboarding email-auth transition bug first, then rerun M10-V with a valid `OPENAI_API_KEY` available to the functions emulator.

#### 2026-03-07 - M10-V follow-up - Onboarding email-auth transition
- Status: Complete
- Summary: Investigated the local onboarding email account path and confirmed the break was in the account-submission path rather than the downstream dashboard transition. Hardened local Firebase emulator wiring to be idempotent and re-applied before Auth calls, moved `Dependencies` service construction behind explicit init-time wiring, changed the onboarding email action to create-first with existing-account fallback, and updated the account step so the password field resigns focus before validation and the footer `Continue` button attempts account creation when credentials are already entered. Live verification now passes: the repaired onboarding UI test creates a fresh Auth-emulator user, advances through profile and focus, lands on the dashboard, and relaunches back into the app shell without showing onboarding again.
- Files changed:
  - `ios/Clearify/Sources/App/ClearifyApp.swift`
  - `ios/Clearify/Sources/App/Dependencies.swift`
  - `ios/Clearify/Sources/Services/AuthService.swift`
  - `ios/Clearify/Sources/Utils/FirebaseEmulatorConfig.swift`
  - `ios/Clearify/Sources/Views/Onboarding/OnboardingView.swift`
- Tests/checks run:
  - Repeated `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard`
  - `curl -s http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key ...` to confirm the Auth emulator itself accepts local email/password signup
  - `rg -n 'providers/firebase.auth/eventTypes/user.create' firebase-debug.log` to verify whether the live app path reached the Auth emulator
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClearifyTests/OnboardingViewModelTests -only-testing:ClearifyTests/AppStateTests`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
  - `xcrun xcresulttool get test-results summary --path /Users/rory/Documents/Clarify AI/tmp-onboarding-fix-rerun.xcresult`
- Acceptance criteria result: Passed for this follow-up. Tapping `Create account with email` now creates the local emulator user on valid input, onboarding advances into the authenticated profile/focus flow, the live debug app reaches dashboard/home, and the repaired onboarding UI regression test passes end to end. Error handling also remains product-safe through `UserFacingErrorMessage` mapping rather than raw technical strings.
- Risks / follow-ups: The onboarding blocker is closed. A system `Save Password?` sheet can appear after account creation during simulator runs, but the repaired flow still reaches profile/dashboard successfully and the regression test passes around it. The brief attempt to move Firebase bootstrap fully into `ClearifyApp.init()` was reverted after a test-run startup crash so the repo is not left with an unverified launch-path refactor.
- Next recommended milestone: Resume M10-V live practice-loop verification from the authenticated app shell, with a valid `OPENAI_API_KEY` configured so analyze/feedback and retry/completion can be verified end to end.

#### 2026-03-07 - M10-V rerun - Live practice loop verification after onboarding auth fix
- Status: Partial
- Summary: Re-ran live local verification after restarting the Firebase emulator stack with a valid `OPENAI_API_KEY` available to the functions worker and confirmed the environment is now ready for local AI-backed checks. Direct live backend verification succeeded for both session-entry modes and quota fairness: two abandoned full-session starts both preserved `remainingFullSessionsThisWeek: 3`, two abandoned quick-drill starts were both allowed, a seeded quick-drill completion immediately caused the next quick-drill start to return `free_quick_drill_limit_reached`, and a seeded full-session completion reduced the next full-session start to `remainingFullSessionsThisWeek: 2`. The rerun also exposed two remaining blockers. First, the live onboarding UI path no longer stalls on account creation, but it still fails to advance from the authenticated profile step to the focus/dashboard step under the repaired UI regression test, so app-side verification of dashboard entry and session launch remains blocked. Second, the live `/analyzeRep` path still fails under the local emulator stack even with `OPENAI_API_KEY` present; direct invocation isolated an emulator-storage configuration problem in backend admin initialization before transcription can succeed reliably in this setup.
- Files changed:
  - `ios/Clearify/UITests/ClearifyUITests.swift`
- Tests/checks run:
  - `test -n "$OPENAI_API_KEY" && echo OPENAI_API_KEY_PRESENT || echo OPENAI_API_KEY_MISSING`
  - `ps aux | rg 'firebase|emulators:start|clearify-5414d'`
  - Restarted `auth`, `functions`, `firestore`, and `storage` emulators with `OPENAI_API_KEY`, OpenJDK 21, and `npx firebase-tools emulators:start --only auth,functions,firestore,storage`
  - `curl -sf http://127.0.0.1:5001/clearify-5414d/us-central1/api/health`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClearifyUITests/ClearifyUITests/testFullSessionStartsFromDashboard -only-testing:ClearifyUITests/ClearifyUITests/testQuickDrillStartsFromDashboard`
  - `xcrun simctl shutdown all`
  - Repeated `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard`
  - Live emulator-auth probes against `/startSession`, `/completeSession`, and `/analyzeRep` using the current request schema
  - Direct Firestore-emulator seeding of session reps to verify `/completeSession` and post-completion quota behavior without relying on the broken analyze path
  - Direct invocation of `backend/functions/lib/src/openaiClient.js` with emulator env vars to isolate the analyze-path failure
- Acceptance criteria result: Partial. Environment readiness is now satisfied: the required emulators are running and the functions worker has `OPENAI_API_KEY`. Live backend verification now covers full-session start, quick-drill start, abandoned-start fairness, and completion-based quota consumption for both modes. The following paths are still not verified end to end through the live app: onboarding to dashboard/home, record/upload/analyze/feedback, retry progression, successful completion UI, and recommendation refresh after completion.
- Risks / follow-ups: There are now two distinct blockers. Product bug: the live onboarding UI path still fails after authenticated account creation because the app does not advance from the profile step to the focus/dashboard step under repeated UI test runs, even though the account is created successfully. Product bug: the backend analyze path still fails in the emulator-backed stack because `storage.bucket()` is not reliably configured under the current admin bootstrap, preventing the local analyze flow from completing. Test harness issue: one intermediate UI rerun hit a simulator `Mach error -308`; after a simulator reset the failure reproduced as the profile-to-focus product issue instead of a launch crash. A direct OpenAI transcription call with the ad hoc generated sample audio also returned `Audio file might be corrupted or unsupported`, so that sample is not valid proof of a successful analyze loop.
- Next recommended milestone: Fix the live onboarding profile-to-focus/dashboard transition first, then fix the backend emulator analyze-path storage configuration and rerun M10-V from the dashboard through analyze, retry, completion, and recommendation refresh.

#### 2026-03-07 - M10-V follow-up - Onboarding profile-to-focus transition
- Status: Partial
- Summary: Investigated the live onboarding blocker past authenticated account creation. The account-creation path still succeeds, but the next onboarding transition remains unstable because the profile step depends on transient onboarding-step and draft-name state while the root view is rehydrating around auth changes. I applied three narrow hardening changes: extracted a shared preferred-name resolver so onboarding and profile completion can reuse the same auth/display/email fallback; gave the onboarding footer step-specific accessibility identifiers so the UI regression hits the actual profile CTA instead of a generic `Continue`; and persisted the in-progress onboarding step plus rehydrated the profile draft whenever the flow re-enters `.profile`. Focused onboarding/app-state unit tests still pass, but the live onboarding UI regression remains blocked: after the authenticated profile CTA tap, `onboarding.footer.focus` still does not appear reliably in the simulator-backed run.
- Files changed:
  - `ios/Clearify/Sources/Services/UserProfileService.swift`
  - `ios/Clearify/Sources/Views/Onboarding/OnboardingView.swift`
  - `ios/Clearify/Tests/OnboardingViewModelTests.swift`
  - `ios/Clearify/UITests/ClearifyUITests.swift`
- Tests/checks run:
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClearifyTests/OnboardingViewModelTests -only-testing:ClearifyTests/AppStateTests`
  - Repeated `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard`
  - Attempted `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
- Acceptance criteria result: Partial. The focused onboarding/app-state tests pass, and the live UI harness is now targeting the actual onboarding CTA controls instead of generic button labels. The primary acceptance criterion is still not met: the local emulator-backed UI flow does not yet reach the focus/dashboard step after authenticated profile submission, so dashboard/home remains unverified through the live onboarding UI path.
- Risks / follow-ups: Root cause is narrowed but not fully eliminated. The live failure no longer looks like stale button targeting; it now points at onboarding progression state itself, likely around the interaction between auth-triggered root rehydration and profile-step draft/step persistence. One later rerun also hit a UITest runner restart (`Executed 0 tests`) after a simulator relaunch, so there is still some harness instability alongside the product-state issue. The generic simulator build was started but not allowed to finish after the repeated live UI failures consumed the available verification window.
- Next recommended milestone: Continue the onboarding profile-to-focus investigation with concrete live state capture at the moment of profile submission, then rerun the onboarding UI regression before resuming the broader M10-V practice-loop verification.

#### 2026-03-07 - AuditV2 - Focused hardening pass
- Status: Complete
- Summary: Closed the highest-risk remaining audit findings without broad redesign. Device-local favorites, saved answers, and archive state are now partitioned by authenticated user ID; saved answers now persist durable local snapshots beyond rolling archive pruning; Home, Progress, and completion recommendations now resolve against the unified scenario source with Firestore updates able to influence recommendations; full-session quota usage now increments on completion instead of session start to match quick drills; and the identified onboarding, settings, account-linking, scenario-library, and generic API surfaces now map failures to product-safe copy instead of surfacing raw technical descriptions.
- Files changed:
  - `backend/functions/src/sessionService.ts`
  - `backend/functions/test/sessionService.test.ts`
  - `docs/state-ownership-contract.md`
  - `ios/Clearify/Clearify.xcodeproj/project.pbxproj`
  - `ios/Clearify/Sources/Networking/APIClient.swift`
  - `ios/Clearify/Sources/Services/FavoriteScenarioStore.swift`
  - `ios/Clearify/Sources/Services/LocalPracticeStore.swift`
  - `ios/Clearify/Sources/Services/SavedAnswerStore.swift`
  - `ios/Clearify/Sources/Services/ScenarioRepository.swift`
  - `ios/Clearify/Sources/Services/UserFacingErrorMessage.swift`
  - `ios/Clearify/Sources/ViewModels/HomeViewModel.swift`
  - `ios/Clearify/Sources/ViewModels/PracticeSessionViewModel.swift`
  - `ios/Clearify/Sources/ViewModels/ProgressViewModel.swift`
  - `ios/Clearify/Sources/ViewModels/ScenarioLibraryViewModel.swift`
  - `ios/Clearify/Sources/Views/Onboarding/OnboardingView.swift`
  - `ios/Clearify/Sources/Views/Practice/PracticeSessionView.swift`
  - `ios/Clearify/Sources/Views/Profile/AccountLinkView.swift`
  - `ios/Clearify/Sources/Views/Profile/ProfileSettingsView.swift`
  - `ios/Clearify/Sources/Views/Progress/ProgressViewScreen.swift`
  - `ios/Clearify/Tests/LocalPersistenceStoresTests.swift`
  - `ios/Clearify/Tests/ScenarioRepositoryTests.swift`
  - `ios/Clearify/Tests/UserFacingErrorMessageTests.swift`
- Tests/checks run:
  - `cd backend/functions && npm test`
  - `cd backend/functions && npm run lint`
  - `cd backend/functions && npm run build`
  - `xcodegen generate` in `ios/Clearify`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'generic/platform=iOS Simulator' build`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClearifyTests`
  - `rg -n "localizedDescription|Request failed \\(" ios/Clearify/Sources backend/functions/src`
- Acceptance criteria result: Passed for this hardening pass. Device-local artifacts no longer cross user boundaries on sign-out/sign-in, saved answers remain accessible after normal archive pruning, remote Firestore scenarios now influence recommendation surfaces through the shared resolver, full sessions and quick drills now consume quota at the same lifecycle point, and the identified user surfaces no longer lead with raw technical error strings.
- Risks / follow-ups: Legacy device-local favorites, saved answers, and archive data had no owner metadata, so the narrow safe migration assigns pre-existing local data to the first authenticated user who opens the upgraded app on that device. Full-session quota fairness is now aligned at completion time, but live end-to-end verification of the record/analyze/complete loop still remains open.
- Next recommended milestone: M10-V — Live practice loop verification

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

- Date: 2026-03-07
- Decision: Migrate legacy unscoped local favorites, saved answers, and archive data into the first authenticated user's device-local scope on upgrade.
- Reason: The legacy device-local stores did not record ownership metadata, so reconstructing the original account owner is impossible. Assigning that data to the first authenticated user is the narrowest safe migration that preserves existing local data without continuing cross-account leakage.
- Impact: Pre-upgrade local artifacts remain available on-device after upgrade, but only within the first post-upgrade signed-in account on that device.

- Date: 2026-03-07
- Decision: Charge free full-session quota on successful completion rather than at session start.
- Reason: Quick drills already consume quota on completion, and charging full sessions at start created an avoidably unfair loss for abandoned starts. Moving both modes to the same lifecycle point is the narrowest consistency fix without redesigning entitlement policy.
- Impact: Quota behavior is now fairer and internally consistent across practice modes, while live end-to-end verification of the session loop remains a separate follow-up.

---

## Current repo truths

### Branding
- Product name: Clearify

### Persistence
- Profile: Firestore-backed with local cache fallback
- Sessions: backend-owned remote model with per-user local archive fallback
- Reps: backend-owned
- Favorites: per-user device-local starred prompts
- Saved answers: per-user device-local durable snapshots
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
- Keep the onboarding profile-footer issue parked for now and continue M10-V from the authenticated dashboard bootstrap path, focusing next on deterministic app-side practice-loop verification from ready-to-record through feedback, retry, completion, and recommendation refresh

## Execution log

### 2026-03-07 - M10-V follow-up - Onboarding profile-to-focus/dashboard stability
- Scope: targeted product-bug fix attempt for the unstable onboarding profile-to-focus/dashboard transition in the live UI flow.
- Root cause found:
  - The profile step still fails to advance reliably in the simulator-backed UI flow even after auth succeeds and the real profile step is visible.
  - New accessibility captures show the app remains on `Set up your profile` after the footer tap, not on the focus step.
  - The footer interaction is unstable because the profile CTA is visible but still not considered hittable by XCUITest during repeated runs, which suggests an unresolved layout / hit-testing interaction rather than a backend or auth blocker.
- Changes attempted:
  - Preserved in-progress onboarding draft state for authenticated users with no remote profile yet by stopping `AppState.hydrate()` from wiping partial onboarding state.
  - Added a forward-only authenticated onboarding progress marker in `OnboardingView` so auth-driven view rebuilds do not intentionally regress `.focus` back to `.profile`.
  - Refactored the setup footer out of the scrolling content and removed the unnecessary async hop for intro/account/profile footer taps so local step transitions happen synchronously on the main thread.
  - Added richer UI-test attachment capture for the post-profile stuck state.
- Tests/checks run:
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ClearifyTests/OnboardingViewModelTests -only-testing:ClearifyTests/AppStateTests`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-stability-1.xcresult`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-stability-2.xcresult`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-stability-3.xcresult`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-stability-4.xcresult`
- What is now verified:
  - Authenticated account creation is still healthy.
  - Focused onboarding/app-state unit tests pass, including a new regression that preserves in-progress onboarding draft state during authenticated hydration with no remote profile.
- What remains blocked:
  - The live UI path still does not advance deterministically from profile to focus/dashboard.
  - Repeated onboarding UI runs remain blocked at the same profile-step transition, so broader session-entry UI verification is still not complete.
  - Backend live analyze/quota verification remains complete from the prior M10-V rerun; the remaining blocker is client-side onboarding stability.

### 2026-03-08 - M10-V follow-up - Onboarding profile-step transition instrumentation
- Scope: narrow root-cause isolation pass for the remaining live UI blocker at the profile footer transition.
- Instrumentation added:
  - Added UI-test-gated onboarding diagnostics so only UITest/debug runs emit trace events.
  - Logged footer tap handler entry, profile validation start/result, profile submission start/end, onboarding step writes, authenticated-progress writes, `AppState` hydration/cache/reset paths, and profile persistence/hydration calls.
  - Added a UITest-only accessibility label that exposes the current onboarding step, authenticated-progress step, submission/auth flags, and the last recorded onboarding diagnostic event.
  - Extended the onboarding UI test to attach that debug state plus footer existence/hittability when the run stalls after the profile step.
- Evidence captured:
  - Serial rerun command: `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-debug-dd test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-debug-3.xcresult`
  - XCTest tapped the visible profile CTA at `27.63s`, then failed waiting for `onboarding.footer.focus`.
  - The attached UITest debug label at failure reported `step=profile authStep=profile submitting=false authenticating=false last=[38] step_write reason=task_authenticated_restore from=profile to=profile`.
  - The same attachment reported `profileFooter.exists=true`, `profileFooter.hittable=true`, `focusFooter.exists=false`, and `focusFooter.hittable=false`.
  - The exported accessibility tree still showed `Set up your profile` and `onboarding.footer.profile`, not the focus step.
- Narrowed root cause:
  - This rerun does not support a hit-testing blocker. XCTest tapped a hittable profile footer and the CTA remained present afterward.
  - This rerun does not support a profile validation failure or profile submission/save failure. The failure snapshot shows `submitting=false`, never reaches the focus step, and the last captured event is not a validation or submission failure.
  - The strongest current evidence is onboarding state reversion or reconciliation after auth-driven restore. By the failure snapshot, the last recorded app-side event is an authenticated restore that writes `.profile` again.
  - The exact earlier event ordering is still not fully proven from this one snapshot because the last-event label can be overwritten by later diagnostics, but the blocker is now narrowed to state mutation/reversion rather than footer hit-testing.
- Tests/checks run:
  - `xcodegen generate`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-debug-dd test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-debug-3.xcresult`
- What is now verified:
  - The instrumentation path is active in UITest runs and captures app-side onboarding state at the failure point.
  - The profile footer exists and is hittable at the moment the UITest taps it.
  - The live UI is still on the profile step at failure time.
  - The latest captured app-side event at failure time is a restore/write back to `.profile`.
- What remains blocked:
  - The precise earlier event sequence around the tap is not yet fully reconstructed from persisted artifacts alone.
  - The exact source of the restoring write still needs one more focused pass to distinguish `OnboardingView` task/on-change restore logic from `AppState` hydration/reconciliation side effects.
  - Broader dashboard/session live verification remains blocked until this onboarding state reversion is fixed.

### 2026-03-08 - M10-V follow-up - Onboarding profile transition ordered event trace
- Scope: final diagnostic-first pass to capture the full ordered event sequence around the profile-step transition without attempting a speculative fix.
- Instrumentation added:
  - Replaced the single last-event debug probe with a bounded ordered event buffer carrying sequence numbers plus monotonic uptime timestamps.
  - Exposed that ordered event buffer through a UITest-only accessibility element so the failing run can export the full transition trace.
  - Renamed the key debug events to the exact transition points under investigation: `footer_tap_enter`, `footer_profile_continue`, `validate_profile_result`, `advance_authenticated_progress_enter`, `advance_authenticated_progress_write_auth_step`, `advance_authenticated_progress_write_step`, `restore_authenticated_progress_enter`, `restore_authenticated_progress_result`, `appstate_hydrate_enter`, and `appstate_hydrate_onboarding_restore`.
  - Updated the UITest attachment capture to include the ordered event buffer and to persist it whenever the profile step stalls.
- Ordered event evidence:
  - Serial failing rerun command: `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-debug-dd test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testFullSessionStartsFromDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-debug-6.xcresult`
  - In the failing run, XCUITest first had to perform repeated swipe-up recovery because `onboarding.footer.profile` was not initially hittable, then performed a coordinate tap on the visible profile footer.
  - The exported ordered buffer from `onboarding-debug-after-profile` ends at:
    - `[38] onboarding_task_start authUserPresent=true`
    - `[39] appstate_hydrate_onboarding_restore reason=onboarding_task_start ...`
    - `[40] restore_authenticated_progress_enter reason=task_authenticated_restore visibleStep=profile authStep=profile target=profile`
    - `[41] step_write reason=task_authenticated_restore from=profile to=profile`
    - `[42] restore_authenticated_progress_result reason=task_authenticated_restore visibleStep=profile authStep=profile`
  - The failing run does include the earlier authenticated handoff path:
    - `[19] auth_uid_change hasUser=true`
    - `[21] restore_authenticated_progress_enter reason=auth_uid_change_restore ... target=profile`
    - `[22] step_write reason=auth_uid_change_restore from=account to=profile`
    - `[26] appstate_hydrate_enter hasSession=true`
    - `[30] appstate_hydrate_profile_loaded hasCompleted=false nameEmpty=false`
    - `[32] email_auth_success`
    - `[33] advance_authenticated_progress_enter reason=email_auth_success ... requested=profile resolved=profile`
    - `[35] auth_progress_write reason=email_auth_success from=account to=profile`
    - `[37] step_write reason=email_auth_success from=account to=profile`
  - The ordered buffer contains no post-profile-tap `footer_tap_enter step=profile`, no `footer_profile_continue`, no `validate_profile_result`, and no `advance_authenticated_progress_enter reason=footer_profile_continue`.
- First divergence from expected flow:
  - Expected after the XCUITest tap: `footer_tap_enter step=profile` -> `footer_profile_continue` -> `validate_profile_result result=passed` -> `advance_authenticated_progress_enter reason=footer_profile_continue` -> writes to `.focus`.
  - Actual failing trace: no app-side footer event is recorded after the tap attempt; the last app-side event remains the pre-tap `task_authenticated_restore` write back to `.profile`.
- Exact state reversion source identified:
  - The write back to `.profile` seen in the failing artifact comes from `OnboardingView`'s authenticated task restore path (`reason=task_authenticated_restore`), not from `AppState.hydrate()` overwriting a later `.focus` mutation.
  - That restore happens before the failing tap attempt and is not evidence of a post-tap reversion from `.focus` back to `.profile`.
- Narrowed root cause:
  - This failing run does not support the theory that the profile CTA fires and then gets reverted.
  - This failing run does not support the theory that `footer_profile_continue` reaches validation or `advanceAuthenticatedProgress`.
  - The blocker in the failing run is the interaction layer around the profile footer: the CTA is visible, but it is not reliably hittable when the UITest helper first checks it, the helper performs scroll recovery, and the resulting tap attempt never dispatches the app-side footer action.
- Recommended code fix:
  - Treat the profile/focus footer as a truly fixed safe-area CTA in the setup flow so it never requires scroll recovery and cannot be partially occluded by the scrolling content.
  - After making that layout fix, keep the ordered event probe in place for one verification rerun, and remove it once `footer_tap_enter step=profile` and `advance_authenticated_progress_enter reason=footer_profile_continue` appear reliably.
- Tests/checks run:
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-debug-dd test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-debug-4.xcresult`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-debug-dd test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testFullSessionStartsFromDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-debug-5.xcresult`
  - `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-debug-dd test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testFullSessionStartsFromDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-debug-6.xcresult`
- What is now verified:
  - The ordered trace now proves the failing run never enters the profile footer handler.
  - The only write back to `.profile` captured in the failing artifact is the pre-tap authenticated restore path.
  - `AppState.hydrate()` loads the not-yet-completed profile during auth handoff, but there is no evidence here that it reverts a later `.focus` write.
  - The root cause has shifted from suspected state reversion to a concrete interaction-dispatch failure on the profile footer in the failing run.

### 2026-03-08 - M10-V fix pass - Setup footer fixed-footer layout
- Status: Partial
- Scope: targeted product fix for the onboarding profile footer interaction bug using the ordered event trace as the source of truth.
- Layout fix applied:
  - Reworked the authenticated setup branch in `OnboardingView` so the setup footer is hosted as a real sibling below the scroll view instead of living inside or being inset onto the scrolling region.
  - Clipped the setup scroll viewport so scrollable profile cards cannot visually or interactively bleed into the footer band.
  - Kept the ordered onboarding debug probe enabled and preserved the UI-test-only event accessibility labels during verification.
  - Tightened the UITest tap helper to wait briefly for hittability before falling back to swipe recovery so the verification harness does not immediately perturb a footer that is still settling.
- Evidence captured:
  - Passing standalone onboarding rerun command: `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-debug-dd test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testOnboardingCompletesOnceAndReturnsToDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-fixed-warm-6.xcresult`
  - Exported ordered attachment from that passing run shows the exact expected profile dispatch sequence:
    - `[43] footer_tap_enter step=profile`
    - `[44] footer_profile_continue nameEmpty=false`
    - `[46] validate_profile_result result=passed`
    - `[47] advance_authenticated_progress_enter reason=footer_profile_continue ... requested=focus resolved=focus`
    - `[48] advance_authenticated_progress_write_auth_step ... target=focus`
    - `[50] advance_authenticated_progress_write_step ... target=focus`
    - `[52] visible_step_changed to=focus`
  - Passing broader dashboard-entry rerun command up through onboarding: `xcodebuild -project ios/Clearify/Clearify.xcodeproj -scheme Clearify -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clearify-onboarding-debug-dd test -parallel-testing-enabled NO -only-testing:ClearifyUITests/ClearifyUITests/testFullSessionStartsFromDashboard -resultBundlePath /Users/rory/Documents/Clarify AI/tmp-onboarding-fixed-dashboard-4.xcresult`
  - In that broader run, the onboarding path advanced `profile -> focus -> dashboard` without swipe recovery on the profile footer. The test then failed later on a separate dashboard assertion waiting for `Start 3-rep practice`, which is outside the profile-footer transition itself.
  - Failure hierarchies before the final clipping change showed the footer outside the scroll-view frame but the profile cards still reporting frames into the footer zone; the final clip change was added specifically to hard-bound the scroll viewport.
- What is now verified:
  - The app-side profile footer path can now dispatch `handleFooterTap()`, pass validation, and write `.focus` under the final layout.
  - The broader dashboard-entry flow is no longer blocked at the onboarding profile footer; its latest failure is after onboarding has already reached the dashboard.
- Remaining blocker / risk:
  - Repeated verification is improved but not fully clean yet. One later standalone rerun still fell back to swipe recovery and stalled at `Expected focus step`, so the footer interaction is not yet proven stable across every serial UITest run.
  - Two additional xcodebuild commands were started for `ClearifyTests/OnboardingViewModelTests`, `ClearifyTests/AppStateTests`, and a generic iOS simulator build, but they were launched against the same DerivedData path and were still compiling at handoff; they should not be treated as completed evidence.
- Files changed:
  - `ios/Clearify/Sources/Views/Onboarding/OnboardingView.swift`
  - `ios/Clearify/UITests/ClearifyUITests.swift`
  - `PLANS.md`
