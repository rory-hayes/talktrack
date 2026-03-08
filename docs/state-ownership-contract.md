# State Ownership Contract

## Purpose

This document defines where core Clearify state lives, who is allowed to write it, how reads should behave, and what user-facing copy is allowed to imply.

This is an engineering contract, not a product vision document.

## Enforcement rules

1. Do not imply cross-device sync for any entity marked `device-local only`.
2. Do not let the iOS client write Firestore directly for any entity marked `backend-owned Firestore`.
3. For entities marked `remote first with local fallback`, treat the fallback as a recovery/read path, not as a second synced source of truth.
4. When local and remote disagree, follow the read-priority rule in the table below.
5. UI copy must not promise stronger persistence than the `User-facing promise` column allows.

## Entity contract

| Entity | Primary source of truth | Write authority | Read priority | Cross-device status | Offline behavior | User-facing promise | Implementation references |
|---|---|---|---|---|---|---|---|
| User profile | Firestore `users/{uid}` with per-user `UserDefaults` cache fallback | Client-writable via `UserProfileService` | Local cache first, then remote refresh/merge | Best effort | Readable offline from cache; writable locally and synced opportunistically | Profile and coaching setup are account-linked, but sync depends on remote availability | `ios/Clearify/Sources/Services/UserProfileService.swift`, `firestore.rules` |
| Onboarding completion state | Effective truth is the user profile (`onboardingCompletedAt` and related fields); `AppState` cache is a bootstrap gate | Client-writable during onboarding/profile save | Local app cache at boot, then hydrated from cached/remote profile | Best effort | Readable/writable locally; remote sync is opportunistic through profile sync | Onboarding/setup can resume from local cache, but account-level completion depends on profile sync | `ios/Clearify/Sources/App/AppState.swift`, `ios/Clearify/Sources/Services/UserProfileService.swift` |
| Sessions | Firestore `sessions/{sessionId}` when backend writes succeed; local archive is fallback only | Backend only for remote session docs; client writes local archive fallback | Remote first with local archive fallback | Best effort | Local completed history is readable offline; remote session creation is not supported offline | Practice history may fall back to this device; do not promise guaranteed synced session history | `backend/functions/src/sessionService.ts`, `backend/functions/src/api.ts`, `ios/Clearify/Sources/Services/LocalPracticeStore.swift`, `firestore.rules` |
| Reps | Firestore `sessions/{sessionId}/reps/{repId}` when backend writes succeed; embedded in local archive fallback | Backend only for remote reps; client stores local archived copies only via completed session archive | Remote first with local archive fallback | Best effort | Readable offline only from local archived sessions | Rep-level transcript/audio review is best effort and can be device-local | `backend/functions/src/api.ts`, `ios/Clearify/Sources/Services/ProgressService.swift`, `ios/Clearify/Sources/Services/LocalPracticeStore.swift`, `firestore.rules` |
| Progress | Firestore `progress_daily/{uid_day}` aggregate; locally derived from archive when remote is missing/unavailable | Backend only for remote aggregate; client derives local fallback snapshots | Remote first with local derived fallback | Best effort | Readable offline from local archive-derived snapshots; not remotely writable offline | Progress can reflect local fallback; do not promise perfect cross-device parity | `backend/functions/src/sessionService.ts`, `ios/Clearify/Sources/Services/ProgressService.swift`, `ios/Clearify/Sources/Services/LocalPracticeStore.swift`, `firestore.rules` |
| Favorites / starred prompts | Per-user `UserDefaults` set of scenario IDs on the current device | Local device only | Local only | Device-local only | Readable and writable offline for the signed-in user on this device | Starred prompts stay on this device for the signed-in account on this device | `ios/Clearify/Sources/Services/FavoriteScenarioStore.swift`, `ios/Clearify/Sources/ViewModels/ScenarioLibraryViewModel.swift` |
| Saved answers | Per-user `UserDefaults` records with durable saved session snapshots plus copied local audio on the current device | Local device only | Local only | Device-local only | Readable and writable offline for the signed-in user on this device | Saved answers stay on this device for the signed-in account on this device, even if older archive rows are pruned | `ios/Clearify/Sources/Services/SavedAnswerStore.swift`, `ios/Clearify/Sources/Services/LocalPracticeStore.swift`, `ios/Clearify/Sources/ViewModels/ProgressViewModel.swift`, `ios/Clearify/Sources/Views/Progress/ProgressViewScreen.swift` |
| Entitlements | StoreKit transaction state mirrored into Firestore `entitlements/{uid}` and `users.planTier`; backend gating reads the Firestore mirror | Client initiates sync; backend writes Firestore entitlement records | Remote mirror first for app/backend behavior; StoreKit restore/resync is the repair path | Best effort | Not a guaranteed offline path; restore/sync requires networked reconciliation | Pro status is account-linked once synced/restored, but copy must only promise implemented unlocks | `ios/Clearify/Sources/Services/EntitlementService.swift`, `backend/functions/src/api.ts`, `backend/functions/src/sessionService.ts`, `firestore.rules` |
| Scenario library | Firestore `scenarios` when available; bundled `scenarios.json` fallback in app bundle | Backend/admin only for Firestore; app bundle is static local fallback | Remote first, then bundled fallback | Shared across devices by backend/app build, but bundled fallback depends on app version | Readable offline from bundled fallback | Scenario catalog is available without network, but remote updates are not guaranteed offline | `ios/Clearify/Sources/Services/ScenarioRepository.swift`, `firestore.rules`, `ios/Clearify/Resources/scenarios.json` |
| Local archive | Per-user device-local JSON archive plus copied audio files in app support directory | Local device only | Local only | Device-local only | Readable and writable offline for the signed-in user on this device | No direct user promise; this is a per-user device-local fallback/store of history | `ios/Clearify/Sources/Services/LocalPracticeStore.swift` |
| Temporary uploaded audio | Firebase Storage under `tmp/{uid}/{sessionId}/rep-{n}.m4a` until backend cleanup | Client uploads; backend deletes after analysis | Not a user-facing read path | Not a user-facing cross-device asset | Not supported as an offline path; upload requires network | Do not imply retained cloud audio access | `ios/Clearify/Sources/Services/StorageUploadService.swift`, `backend/functions/src/api.ts`, `storage.rules` |

## Read-precedence rules

### Profile and onboarding
- Boot can use cached `AppState` and cached profile data immediately.
- Hydration should then reconcile against the cached/remote profile.
- Remote profile fields win unless `UserProfileService.merged(...)` explicitly preserves completed local onboarding state.

### Sessions, reps, and progress
- Prefer remote Firestore data when present.
- If remote reads fail or return nothing, use the local archive fallback.
- Local fallback is not an independent sync system and should not be treated as globally authoritative.

### Favorites and saved answers
- Treat these as device-local.
- Do not add account-backed copy around these entities.
- Scope these entities by authenticated user ID on the current device.
- Saved answers should remain readable from their durable local snapshot even after rolling archive pruning.

### Entitlements
- The App Store is the billing authority.
- Firestore is the operational source used by app/backend gating after sync.
- If the mirror is stale, the repair path is StoreKit restore/resync, not local persistence.

## Non-goals for this contract

This document does not change:
- session sync behavior
- entitlement scope

Those changes belong to later milestones.
