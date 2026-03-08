# Clearify Audit V2

Updated: 2026-03-07

## 1. Executive summary

Clearify is an iOS-first AI speaking coach for workplace communication, interview preparation, and customer-facing conversations. The shipped product loop is:

1. User signs in and completes onboarding.
2. User selects or accepts a recommended speaking prompt.
3. User records a spoken answer.
4. Backend transcribes and scores the answer.
5. App returns one focused coaching correction and guides the user into a retry loop.
6. Completed sessions feed streaks, progress summaries, saved answers, and recommended follow-up practice.

The currently reachable product is a native SwiftUI iPhone app with a Firebase-backed practice loop, a 3-tab shell (`Home`, `Progress`, `Profile`), a prompt library sheet, a practice session sheet, and a paywall sheet. There is no web app, Android app, or admin surface in this repo.

The application purpose is consistent across the codebase: help users become more concise, structured, and confident in realistic spoken work scenarios by combining short speaking reps with AI feedback and visible progress tracking.

## 2. What the application is for

At a product level, Clearify is built to coach spoken communication rather than written communication. The scenarios, scoring, and UX are all optimized around short spoken answers to realistic prompts.

The main user problems it addresses are:

- Rambling or unclear interview answers
- Weak structure in workplace updates and explanations
- Poor conciseness in fast work conversations
- Delivery issues such as filler words, pace, and weak endings
- Lack of repetition and measurable progress in communication practice

The app personalizes practice using four user inputs captured during onboarding and profile editing:

- `Scenario mode`: `Interview`, `Workplace`, `Customer`
- `Role track`: `General`, `Software Engineer`, `Product Manager`, `Account Executive`, `Analyst`, `Customer Success`
- `Experience level`: `Switching / Starting`, `0-1 years`, `2-4 years`, `5-7 years`
- `Primary coaching focus`: `Structure`, `Clarity`, `Conciseness`, `Delivery`

The scenario system currently contains `170` bundled prompts:

- `50` interview
- `80` workplace
- `40` customer

## 3. Current architecture

### Client

- Native SwiftUI app in `ios/Clearify`
- App shell: bootstrapping -> onboarding -> 3-tab app shell
- Firebase Auth for identity
- Firestore for profile, scenarios, remote sessions, progress, and entitlements
- Firebase Storage for temporary uploaded audio
- StoreKit for subscription products and restore
- Analytics and crash reporting via Firebase Analytics and Crashlytics

### Backend

- Firebase Cloud Functions Express app in `backend/functions`
- Public API surface:
  - `GET /health`
  - `POST /startSession`
  - `POST /analyzeRep`
  - `POST /completeSession`
  - `POST /syncEntitlement`
- OpenAI usage is backend-only

### Practice/scoring contract

- `Full session` = `3` reps
- `Quick drill` = `1` rep
- Score pillars:
  - Structure
  - Clarity
  - Conciseness
  - Delivery
- Feedback contract per analyzed rep:
  - one main improvement
  - one suggested structure
  - one rewritten example
  - one retry instruction

### State ownership summary

- User profile: Firestore with local cache fallback
- Onboarding gate: local `AppState` cache, then hydrated from profile
- Sessions, reps, progress: remote-first with local archive fallback
- Starred prompts: device-local only
- Saved answers: device-local only
- Entitlements: StoreKit mirrored into Firestore and enforced from the synced mirror

## 4. Primary implementation anchors

These are the files a new team should start with:

- App shell and navigation: `ios/Clearify/Sources/Views/RootView.swift`
- Boot and dependencies: `ios/Clearify/Sources/App/ClearifyApp.swift`, `ios/Clearify/Sources/App/Dependencies.swift`, `ios/Clearify/Sources/App/AppState.swift`
- Onboarding flow: `ios/Clearify/Sources/Views/Onboarding/OnboardingView.swift`, `ios/Clearify/Sources/ViewModels/OnboardingViewModel.swift`
- Home dashboard: `ios/Clearify/Sources/Views/Home/HomeView.swift`, `ios/Clearify/Sources/ViewModels/HomeViewModel.swift`
- Prompt library: `ios/Clearify/Sources/Views/Home/ScenarioLibraryView.swift`, `ios/Clearify/Sources/ViewModels/ScenarioLibraryViewModel.swift`
- Practice loop: `ios/Clearify/Sources/Views/Practice/PracticeSessionView.swift`, `ios/Clearify/Sources/ViewModels/PracticeSessionViewModel.swift`
- Progress surface: `ios/Clearify/Sources/Views/Progress/ProgressViewScreen.swift`, `ios/Clearify/Sources/ViewModels/ProgressViewModel.swift`
- Profile and settings: `ios/Clearify/Sources/Views/Profile/ProfileSettingsView.swift`, `ios/Clearify/Sources/ViewModels/ProfileSettingsSubmission.swift`
- Scenario ranking/data: `ios/Clearify/Sources/Services/ScenarioRepository.swift`
- Remote practice APIs: `ios/Clearify/Sources/Services/PracticeSessionService.swift`, `backend/functions/src/api.ts`, `backend/functions/src/sessionService.ts`
- Persistence/local archive: `ios/Clearify/Sources/Services/LocalPracticeStore.swift`, `ios/Clearify/Sources/Services/FavoriteScenarioStore.swift`, `ios/Clearify/Sources/Services/SavedAnswerStore.swift`
- Profile sync: `ios/Clearify/Sources/Services/UserProfileService.swift`
- Entitlements/paywall: `ios/Clearify/Sources/Services/EntitlementService.swift`, `ios/Clearify/Sources/Services/SubscriptionService.swift`, `ios/Clearify/Sources/Views/Paywall/PaywallView.swift`
- State ownership contract: `docs/state-ownership-contract.md`

## 5. Implemented screens and surfaces

| Surface | Reachable in normal flow | Purpose | Primary actions |
|---|---|---|---|
| Bootstrapping screen | Yes | Hydrates auth/profile state before showing app shell | Wait for hydration |
| Onboarding intro 1 | Yes | Introduces scenario practice | Continue, Skip |
| Onboarding intro 2 | Yes | Introduces AI coaching | Continue, Skip |
| Onboarding intro 3 | Yes | Introduces streak/progress loop | Set up my plan, Skip |
| Onboarding account step | Yes | Create or recover account access using Google or email/password | Continue with Google, Create account with email, Continue |
| Onboarding profile step | Yes | Capture first name, experience level, initial coaching focus | Edit name, select experience, select focus, Continue |
| Onboarding training path step | Yes | Set default mode and role track | Select mode, select role track, Go to dashboard |
| Home tab | Yes | Main dashboard with recommendation, prompt search, and recent momentum | Change mode, open library, start full session, start quick drill, open Progress |
| Scenario library sheet | Yes | Browse/search/filter full prompt catalog | Search, switch mode, switch role, star prompt, start Full, start Quick |
| Practice session sheet | Yes | Record answers, receive feedback, retry, complete session | Record/stop, retry, save answer, start follow-up practice, back to Home |
| Paywall sheet | Yes, but only after limit block | Sell/restore Pro when free-tier limit blocks session start | Buy product, Restore Purchases, Not now |
| Progress tab | Yes | Show weekly trend, focus summary, recommended next practice, saved answers, recent history | Start recommended practice, replay local audio, practice a saved answer again |
| Profile tab | Yes | Show account summary and current coaching setup | Edit Profile, Sign Out |
| Profile settings sheet | Yes | Edit name, experience, focus, default mode, role track | Save, Close |
| Account link sheet | No | Intended account-link flow for anonymous/local users | Apple link, email link |

## 6. Main user click paths

### First-run onboarding path

1. Launch app.
2. Bootstrapping screen appears.
3. User taps through three intro cards or taps `Skip`.
4. User lands on account step.
5. User signs in with Google or enters email + password.
6. User completes profile step:
   - first name
   - experience level
   - initial coaching focus
7. User completes training path step:
   - default mode
   - role track
8. User taps `Go to dashboard`.
9. User lands on `Home`.

### Returning signed-in user path

1. Launch app.
2. Bootstrapping hydrates cached and remote state.
3. If onboarding is already complete, user goes straight to the tab shell.
4. Last-selected tab is not persisted; app re-enters through `Home`.

### Home -> recommended practice path

1. User opens `Home`.
2. User optionally changes mode using the horizontal mode pills.
3. User sees the `Start here` recommendation card.
4. User taps:
   - `Start 3-rep practice`, or
   - `Take 1 quick drill`
5. Practice session sheet opens.

### Home -> alternate prompt path

1. User opens `Home`.
2. User uses `Search this mode` in the `Need a different prompt?` section.
3. User taps a scenario card from the horizontal results list.
4. Practice session opens as a full session.

### Home -> full library path

1. User opens `Home`.
2. User taps:
   - top-right avatar circle
   - `Browse prompts`
   - `Open library`
3. Scenario library sheet opens.
4. User can:
   - search scenarios
   - switch mode
   - change role track
   - toggle `Starred only`
   - star/unstar prompts
5. User taps `Full` or `Quick` on a prompt.
6. Library dismisses and practice sheet opens.

### Practice session loop path

1. Practice sheet opens.
2. App calls backend `startSession`.
3. If allowed, session enters `ready to record`.
4. User taps mic button to start recording.
5. User taps stop, or app auto-stops at `90` seconds.
6. Audio uploads to Storage.
7. Backend transcribes and scores the rep.
8. App shows:
   - score breakdown and coaching card
   - retry instruction
   - before/after comparison after multiple reps
   - rep timeline
9. If full session and more reps remain, user taps retry CTA and records again.
10. After final rep, app completes session and shows completion summary.
11. From completion, user can:
   - practice a related prompt
   - run a quick drill on the same prompt
   - save the answer on this device
   - go back to Home

### Limit reached -> paywall path

1. User tries to start a practice session.
2. Backend denies `startSession` because of free-tier usage.
3. Practice sheet stays unavailable and opens the paywall.
4. User can:
   - purchase a plan
   - restore purchases
   - dismiss with `Not now`

### Progress path

1. User taps `Progress` in bottom navigation, or taps the `Progress` action in `Recent momentum`.
2. User sees:
   - weekly summary
   - next recommended practice
   - current focus summary
   - saved answers on this device
   - recent session history
3. User can:
   - start the recommended next practice
   - replay local audio from saved/history reps
   - open a prior saved answer as a new full session

### Profile/settings path

1. User taps `Profile` in bottom navigation.
2. User taps `Edit Profile`.
3. Settings sheet opens.
4. User edits name, experience level, focus, default mode, and role track.
5. User taps `Save`.
6. App updates `AppState`, caches locally, and syncs profile best-effort to Firestore.

### Sign-out path

1. User opens `Profile`.
2. User taps `Sign Out`.
3. Firebase auth session ends.
4. App resets onboarding/profile gate state.
5. User returns to onboarding/account flow on next entry.

## 7. Feature and functionality audit

### Authentication and account state

Implemented:

- Google Sign-In
- Email/password account flow
- Persistent signed-in session via Firebase Auth
- Sign out
- Profile hydration from Firestore with local cache fallback

Not implemented in reachable flow:

- Anonymous auth
- Password reset
- Apple Sign-In in onboarding or profile
- Any reachable account-link conversion flow

### Onboarding and personalization

Implemented:

- 3-page intro education flow
- First-name capture
- Experience-level capture
- Initial coaching-focus capture
- Default mode selection
- Role-track selection
- Local onboarding cache gate
- Best-effort sync of onboarding/profile data to Firestore

### Home and recommendation system

Implemented:

- Personalized greeting
- Streak and recent average summary chips
- Mode switcher
- Primary recommended prompt
- Two-entry practice CTA model:
  - `Start 3-rep practice`
  - `Take 1 quick drill`
- In-mode search for alternate prompts
- Recent momentum preview

### Scenario library

Implemented:

- Search across prompt text, coaching rationale, and structure hint
- Mode filter
- Role-track filter
- Device-local starred prompts
- `Starred only` filter
- Full-session and quick-drill launch from each prompt card

### Practice loop

Implemented:

- Microphone permission handling
- Local audio recording
- 30-second minimum duration
- 90-second auto-stop cap
- Upload to Firebase Storage
- Backend transcription and scoring
- Structured feedback card
- Explicit retry loop for multi-rep sessions
- Before/after comparison
- Rep timeline
- Completion summary with recommended next action
- Save-answer action on completion
- Local fallback completion if backend completion sync fails

### Progress/history surface

Implemented:

- Weekly score summary
- Streak display
- Sparkline when enough data exists
- Recommended next practice card
- Current coaching focus diagnosis
- Saved answers section
- Recent session history
- Local audio replay from archived sessions
- Restart a saved answer as a new full session

### Monetization

Implemented:

- Free-tier gating from backend
- Paywall shown when gating blocks session start
- Product loading from StoreKit
- Purchase flow
- Restore purchases
- Entitlement sync into Firestore

Current plan rules:

- Free: `3` full sessions per week
- Free: `1` quick drill per day
- Pro: backend treats active synced entitlement as unlimited for those gates

### Observability and testing

Implemented:

- Firebase Analytics event logging
- Crashlytics breadcrumbs and error recording
- Unit test targets for:
  - `AppState`
  - `OnboardingViewModel`
  - `ProfileSettingsSubmission`
  - `PracticeSessionViewModel`
  - `ProgressViewModel`
- UI test target with a first-run onboarding-to-dashboard flow
- UI test reset helper that clears auth, defaults, and local archive folders when launched with `UITEST_RESET_STATE`

## 8. Persistence and state behavior

### Account-linked or remote-backed

- Profile and coaching setup are account-linked, with local cache fallback
- Remote sessions, reps, daily progress, and entitlement records are backend-owned Firestore data
- Scenario catalog can come from Firestore when seeded, with bundled fallback

### Device-local only

- Starred prompts
- Saved answers
- Local archived sessions and copied local audio

### Important persistence details

- Local archive retention is capped at `20` completed sessions
- Audio for archived sessions older than the retained set is pruned
- Temporary cloud audio is deleted after backend analysis
- Sign-out does not clear the local archive, saved answers, or starred prompts
- Saved answers are pointers into the local archive, so if a session ages out of the retained archive the saved answer disappears from the UI

## 9. Current gaps, risks, and handover notes

### 1. Remote scenario updates do not drive recommendations

The app can read remote Firestore scenarios for the library list, but the main recommendation methods (`personalizedRecommendation` and `nextScenario`) operate only on the bundled local scenario catalog. In practice, Home recommendations, Progress recommendations, and completion follow-up recommendations ignore newly added Firestore scenarios unless the app bundle is also updated.

### 2. Device-local practice data is not user-scoped

Saved answers, starred prompts, and the local archived session store persist across sign-out and are not partitioned by Firebase user ID. On a shared device, a new signed-in user can inherit device-local stars and saved answers from a prior user, and fallback/local-history behavior can surface cross-account residue.

### 3. Saved answers are bounded by archive retention

Saved answers are not separate persisted documents. They are just session IDs stored in `UserDefaults` that resolve against the retained local archive. Because the local archive keeps only `20` sessions, older saved answers silently disappear once the underlying archived session and audio are pruned.

### 4. Apple Sign-In exists in code but not in the live app flow

`AuthService` supports Apple auth and `AccountLinkView` renders an Apple button, but that screen is not referenced from the active navigation tree and there is no anonymous-auth path that would require post-hoc account linking. Another team taking over should treat this as dormant code, not a shipped feature.

### 5. Paywall is reactive only

There is no proactive upgrade or subscription-management entry point in the app shell. The paywall currently appears only after a practice start is blocked by backend quota enforcement.

### 6. Free-plan quota accounting is asymmetric

Full-session usage is consumed on `startSession`, while quick-drill usage increments on `completeSession`. This means abandoned full sessions can burn weekly allowance even if the user never records a rep, while quick drills are only counted after completion.

### 7. Email flow is account-creation-first and lacks recovery UX

The email flow attempts sign-in first and then falls back to create-user on failure. There is no password-reset UX and no dedicated returning-email-user screen. Existing users who enter the wrong password will fall through into Firebase account-creation errors rather than a cleaner recovery path.

### 8. Branding is still mixed between `Clearify` and `TalkTrack`

User-facing copy is mostly `Clearify`, but internal naming still uses `TalkTrack` in the design system, local archive folder, and legacy `UserDefaults` keys. Subscription product IDs also support both naming conventions. This is survivable, but a new team should treat branding cleanup as unfinished work rather than assume the mixed naming is intentional long-term structure.

### 9. No in-app management UI for device-local artifacts

Users can save an answer and star prompts, but there is no dedicated management screen for clearing saved answers, clearing starred prompts, or deleting local archive data. Deletion helpers exist in storage code, but they are not exposed in the UI.

## 10. Operational notes for the receiving team

- Debug builds point to local Firebase emulators when `CLEARIFY_API_BASE_URL` resolves to `127.0.0.1` or `localhost`
- Release configuration expects a deployed Cloud Functions API URL
- Required runtime dependencies:
  - Firebase Auth
  - Firestore
  - Storage
  - Cloud Functions
  - StoreKit product configuration
  - OpenAI API key for backend functions
- Scenario operations rely on backend scripts for seeding/exporting the library
- The repo already contains supporting docs for Firebase production setup and state ownership

## 11. Verification performed for this audit

- Reviewed current iOS app shell, onboarding, home, scenario library, practice, progress, profile, settings, paywall, auth, profile sync, entitlement sync, local persistence, and backend session logic
- Verified bundled scenario count from `ios/Clearify/Resources/scenarios.json`
- Ran backend checks in `backend/functions`:
  - `npm run lint`
  - `npm run test`
- Result: backend lint passed and backend tests passed (`29` tests)

Not run in this audit pass:

- `xcodebuild` compile/test pass for the iOS app
- Simulator/manual UI walkthrough beyond code inspection

