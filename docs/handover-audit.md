# Clearify Handover Audit

Updated: 2026-03-06

## 1. What this application is

Clearify is an iOS-first AI speaking coach for workplace communication and interview preparation. The core product loop is:

1. User selects a realistic speaking scenario.
2. User records a spoken answer.
3. Backend transcribes and scores the answer across four pillars: structure, clarity, conciseness, and delivery.
4. User receives one main coaching correction, one suggested structure, one rewritten example, and one retry instruction.
5. Completed sessions feed streaks, daily progress, saved answers, and recommended future prompts.

The product intent is stated in the repo README and architecture docs, and the implementation matches that intent at a high level.

## 2. Architecture summary

### Client

- Native SwiftUI app under `ios/Clearify`.
- Main shell is bootstrapping -> onboarding -> tabbed app shell.
- Firebase Auth handles identity.
- Firestore is used for users, sessions, reps, daily progress, entitlements, and scenarios.
- Firebase Storage is used for temporary practice audio uploads.
- StoreKit is used for Pro subscriptions.

### Server

- Firebase Cloud Functions Express app under `backend/functions`.
- Exposed endpoints:
  - `POST /startSession`
  - `POST /analyzeRep`
  - `POST /completeSession`
  - `POST /syncEntitlement`
- OpenAI is only called from the backend, never from the iOS client.

### Data/security

- Client can read its own user/session/progress/entitlement data.
- Client cannot write sessions, reps, progress, or entitlements directly; those writes are server-only.
- Storage is locked down to `tmp/{uid}/...` for the authenticated owner.

## 3. Reachable screens and user-facing surfaces

### Core reachable screens

1. Bootstrapping screen
   - Loads coaching profile and session context before the app shell appears.

2. Onboarding intro page 1
   - "Practice real work moments"

3. Onboarding intro page 2
   - "Get one clear coaching point"

4. Onboarding intro page 3
   - "See progress build daily"

5. Onboarding account screen
   - Email/password path
   - Google sign-in path

6. Onboarding profile screen
   - Preferred name
   - Experience level
   - Initial coaching focus

7. Onboarding training path screen
   - Default scenario mode
   - Role track

8. Home tab
   - Personalized greeting
   - Mode switcher
   - Primary "Start here" recommendation
   - Alternate prompt search and scenario carousel
   - Recent momentum preview

9. Scenario library sheet
   - Search
   - Mode filters
   - Role-track filter
   - Star toggle
   - Start full session / quick drill

10. Practice session sheet
   - Full session: 3 reps
   - Quick drill: 1 rep
   - Recording, upload, and analysis loop
   - Feedback card focused on one main fix, one structure, one example, and one retry instruction
   - Explicit retry CTA between reps
   - Before/after comparison
   - Rep timeline
   - Completion summary that explains what changed and recommends the best next move
   - Completion actions: related prompt, quick drill, save best answer, back to Home

11. Paywall sheet
   - Pro purchase options
   - Restore purchases

12. Progress tab
   - Weekly summary
   - Coaching focus summary
   - Practice-next recommendation
   - Saved answers
   - Recent session history
   - Local audio replay

13. Profile tab
   - Account summary
   - Current practice setup
   - Sign out

14. Profile settings sheet
   - Edit preferred name, experience level, focus, default mode, role track

### Implemented but not wired into the main navigation

1. `AccountLinkView`
   - Supports Apple Sign In and email-based account linking.
   - Intended for converting an anonymous/local user into a persistent account.
   - I found no active navigation path to this screen in the current app shell.

## 4. Main click paths

### First-run path

1. Launch app.
2. Bootstrapping screen appears.
3. User sees three onboarding intro cards.
4. User continues or skips.
5. User creates/signs into an account with Google or email.
6. User enters first name, experience level, and initial focus.
7. User chooses default mode and role track.
8. User lands on the Home tab dashboard.

### Returning signed-in user path

1. Launch app.
2. Bootstrapping screen hydrates user state.
3. User is sent directly to the tab shell if onboarding is already complete.

### Home -> practice path

1. Home tab.
2. Optionally change mode via Interview / Workplace / Customer pills.
3. Start from:
   - "Start 3-rep practice"
   - "Take 1 quick drill"
   - scenario carousel card
   - scenario library sheet
4. Practice session sheet opens.
5. Practice sheet tells the user what to do next for the current rep.
6. User records answer.
7. User stops recording.
8. App uploads audio, asks backend for analysis, and renders feedback.
9. If full session, the app presents a clear retry action for the next rep.
10. If full session, user repeats until 3 reps are complete.
11. Completion state shows final score, delta, and next actions.
12. Completion state explains what changed, recommends one best next move, and keeps alternate actions available without making them equally prominent.

### Home -> library -> practice path

1. Home tab.
2. Tap avatar circle or "Browse prompts" / "Open library".
3. Scenario library sheet opens.
4. Search/filter/favorite as needed.
5. Tap Full or Quick on any scenario.
6. Library dismisses.
7. Practice session sheet opens.

### Home -> progress path

1. Home tab.
2. Tap bottom navigation "Progress" or tap the section action in "Recent momentum".
3. Progress tab opens.
4. User can:
   - review weekly trend
   - inspect saved answers
   - open recent session details
   - replay locally stored audio
   - restart a saved answer as a new full session

### Home/Profile -> settings path

1. Bottom navigation -> Profile.
2. Tap "Edit Profile".
3. Settings sheet opens.
4. User updates name, experience, focus, default mode, and role track.
5. Tap Save.
6. App persists changes locally and syncs them to Firestore when possible.

### Limit reached -> paywall path

1. User starts a session.
2. Backend checks free-tier usage rules.
3. If blocked, app opens paywall sheet instead of starting the session.
4. User can buy, restore, or dismiss.

## 5. Feature audit

### Authentication and account state

- Implemented:
  - Email/password sign-in or create-account flow.
  - Google Sign-In.
  - Sign out.
  - Firestore profile hydration with local cache fallback.

- Notes:
  - The onboarding account step is mandatory for the reachable app flow.
  - There is no reachable guest mode in the current app shell.

### Onboarding and personalization

- Implemented:
  - Intro education flow.
  - Preferred name capture.
  - Experience level capture.
  - Initial coaching focus capture.
  - Default scenario mode selection.
  - Role track selection.
  - Persisted app state cache in `UserDefaults`.

- Product effect:
  - Personalized recommendation and scenario ranking use mode, role track, experience, and weakest focus.

### Scenario library and recommendation

- Implemented:
  - 170-scenario bundled fallback library.
  - Firestore-backed remote scenario source if seeded.
  - Ranking logic based on mode, weak focus, role track, and experience level.
  - Daily recommendation.
  - Library search.
  - Device-local starred prompts in the library view.

- Scenario inventory:
  - 50 interview
  - 80 workplace
  - 40 customer

### Practice sessions

- Implemented:
  - Full session = 3 reps.
  - Quick drill = 1 rep.
  - Microphone permission request.
  - 30-second minimum and 90-second auto-stop ceiling.
  - Upload audio to Firebase Storage.
  - Analyze each rep.
  - Show structured feedback after each rep.
  - Persist completed session locally.
  - Completion state with:
    - final score, delta, and 7-day average
    - explicit “what changed” summary
    - one recommended next action
    - alternate follow-up actions

### AI analysis

- Implemented:
  - Audio transcription through OpenAI.
  - Structured rubric feedback through OpenAI JSON schema.
  - Heuristic speech metrics:
    - WPM
    - filler count/rate
    - estimated pauses
    - pacing band
    - filler hotspot
    - opening-too-long / weak-conclusion flags

- Resilience behavior:
  - If feedback generation fails after transcription succeeds, backend falls back to deterministic feedback.
  - If the final session sync fails, the app still produces a local completion object and stores the session locally.

### Progress and history

- Implemented:
  - Weekly average score.
  - Daily streak.
  - Practice-next recommendation grounded in selected mode, role track, and current weak focus.
  - Weakest-focus summary.
  - Recent-win and recurring-issue framing.
  - Recent sessions list.
  - Before/after transcript comparison.
  - Saved answers list.
  - Local audio playback for stored reps.

- Data source behavior:
  - Remote Firestore is preferred for sessions/progress.
  - Local archive is used as fallback when remote data is missing or unavailable.

### Subscription and entitlements

- Implemented:
  - StoreKit product loading.
  - Purchase.
  - Restore purchases.
  - Entitlement sync to backend.
  - Free-tier gating.

- Free-tier rules currently enforced:
  - 3 full sessions per week
  - 1 quick drill per day

## 6. Persistence and backend data model

### Firestore collections in use

- `users`
- `sessions`
- `sessions/{sessionId}/reps`
- `progress_daily`
- `usage_weekly`
- `entitlements`
- `scenarios`

### Storage paths

- Temporary uploaded audio: `tmp/{uid}/{sessionId}/rep-{n}.m4a`

### Local-only persistence

- Session archive JSON in app support directory
- Saved-answer IDs in `UserDefaults`
- Starred scenario IDs in `UserDefaults`
- Copied audio files for retained sessions

### Local retention behavior

- Local archive keeps only the most recent 20 completed sessions.
- Audio is pruned for sessions that fall outside that retained set.

## 7. Important implementation details for the next team

### What is fully real versus marketing copy

- The main product loop is real and implemented end-to-end.
- The app is not a static prototype; it has a functioning client/server architecture, actual storage rules, session documents, rep documents, progress aggregation, and subscription plumbing.

### Recommended prompts are personalized, but not heavily adaptive yet

- Recommendation logic is deterministic scoring over the current scenario set.
- There is no ML-based personalization layer beyond ranking by metadata and weak-focus inference.

### Sync strategy is intentionally defensive

- User profile is cached locally and remote sync happens opportunistically.
- Session completion can fall back to a locally generated completion summary if backend sync fails.
- Progress/history read paths fall back to local storage when Firestore is unavailable.

## 8. Gaps, inconsistencies, and handover risks

These are the main issues the next team should know before taking ownership.

### 1. Legacy TalkTrack identifiers remain internally

- Reachable user-facing branding now uses `Clearify`.
- Internal UI system names and some local-only storage identifiers still use `TalkTrack`.
- This is technical debt to clean up later, but it is no longer a visible product-brand mismatch.

### 2. Saved answers and favorites are local-only, not account-synced

- The current UI now calls out these items as device-local where they are surfaced.
- In implementation:
  - favorites live in `UserDefaults`
  - saved-answer IDs live in `UserDefaults`
  - saved sessions are resolved from the local archive only
- Result: these do not automatically follow the user across devices.
- This is now the explicit current truth model, not an accidental fallback.

### 3. Apple Sign In is implemented, but not exposed in the primary onboarding path

- README/setup instructs Apple auth enablement.
- Auth service supports Apple auth.
- Reachable onboarding only offers Google and email.
- Apple Sign In appears only in the hidden `AccountLinkView`.

### 4. There is a hidden account-linking screen with no navigation path

- `AccountLinkView` looks intended for a guest-to-account conversion flow.
- I found no active route to it from the current shell.

### 5. Free-tier usage is counted asymmetrically

- Full session quota is consumed at session start.
- Quick drill quota is counted when the session completes.
- This means abandoning a full session still burns quota, while abandoning a quick drill does not.

### 6. Test coverage is light on the client

- Backend has lint + unit tests for scoring/metrics/time helpers.
- iOS has a single UITest covering onboarding -> dashboard -> profile -> session entry.
- I did not find deeper automated coverage for the main practice loop, purchases, or progress syncing.

## 9. Recommended handover priorities

If another team is taking this over, the first cleanup items I would recommend are:

1. If product later wants cross-device favorites or saved answers, move them to Firestore and update the state-ownership contract.
2. Expose or remove Apple Sign In and `AccountLinkView`.
3. Decide whether to retire internal `TalkTrack` identifiers and local storage naming as a follow-up cleanup.
4. Decide whether full-session quota should be charged on start or completion.
5. Add broader automated coverage for the practice loop, purchases, and progress syncing.

## 10. Verification performed for this audit

- Read the SwiftUI app shell, views, view models, services, models, backend functions, security rules, scenario scripts, and setup docs.
- Confirmed bundled scenario counts:
  - 170 total
  - 50 interview
  - 80 workplace
  - 40 customer
- Ran backend verification:
  - `npm run lint`
  - `npm run test`
- Result:
  - lint passed
  - 3 test files passed
  - 6 tests passed
