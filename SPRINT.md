# SPRINT.md

## Sprint name
Clearify hardening sprint

## Sprint objective
Turn Clearify into a more trustworthy, internally consistent, production-grade app by executing tightly scoped milestones in the correct order.

## Sprint rules
- Complete milestones in order unless explicitly reprioritized
- Do not skip acceptance criteria
- Do not mark a milestone complete without updating `PLANS.md`
- Run relevant checks for every milestone

---

# Milestones

## M1 — Brand consistency cleanup

### Goal
Remove remaining user-visible naming inconsistencies so the app presents a single coherent product identity.

### Tasks
- Audit user-visible strings for `TalkTrack`
- Replace reachable user-visible references with `Clearify`
- Check onboarding, settings, profile, fallback strings, and error copy
- Avoid risky storage or data migrations unless required for correctness

### Files likely involved
- SwiftUI views
- constants or strings sources
- onboarding surfaces
- profile/settings surfaces
- docs where user-visible behavior is described

### Tests/checks
- Search repo for `TalkTrack`
- Run relevant iOS checks if user-visible screens changed
- Verify no reachable UI still shows old branding

### Acceptance criteria
- No reachable production flow shows `TalkTrack`
- Branding is consistent across onboarding, home, progress, profile, settings, and paywall

### Definition of done
- Branding cleanup implemented
- Relevant checks run
- `PLANS.md` updated

---

## M2 — Misleading label and copy cleanup

### Goal
Remove user-visible labels and placeholders that overpromise or misrepresent behavior.

### Tasks
- Fix Home “Favorites” label or behavior
- Fix Home search placeholder or implement missing behavior if safely in scope
- Audit related misleading copy across Home, Progress, and Profile
- Ensure copy matches product reality

### Tests/checks
- Manual or automated verification of corrected labels
- Confirm behavior matches displayed copy

### Acceptance criteria
- No major screen label claims unsupported behavior
- Search and favorites language matches implementation

### Definition of done
- Copy and behavior aligned
- `PLANS.md` updated

---

## M3 — Dead control audit and fixes

### Goal
Remove or correctly wire visible controls that currently do nothing.

### Tasks
- Audit visible tappable controls
- Fix or remove no-op controls
- Confirm navigation and action behavior is meaningful

### Tests/checks
- Tap-path verification on affected screens
- UI tests if present and practical

### Acceptance criteria
- No visible tappable control is decorative-only
- All remaining controls have meaningful behavior

### Definition of done
- Dead controls resolved
- `PLANS.md` updated

---

## M4 — Paywall reason and message cleanup

### Goal
Replace raw internal limit and reason strings with production-grade user messaging.

### Tasks
- Map backend reason codes to friendly copy
- Ensure internal strings do not leak into UI
- Review paywall and gating-related error surfaces
- Keep copy aligned to actual entitlement behavior

### Tests/checks
- Backend, unit, or UI tests where practical
- Verify limit hits show readable copy

### Acceptance criteria
- No raw internal reason codes shown to users
- Paywall and gating copy is clear and calm

### Definition of done
- Mapping implemented
- `PLANS.md` updated

---

## M5 — Persistence promise alignment

### Goal
Ensure the app does not imply stronger sync or persistence guarantees than it actually provides.

### Tasks
- Audit copy around progress, saved answers, favorites, and account persistence
- Correct misleading product language
- Keep scope to truth alignment, not broad sync implementation

### Tests/checks
- Review screens with persistence-related copy
- Verify user-facing language matches current implementation

### Acceptance criteria
- No misleading cross-device or account-backed persistence claims remain

### Definition of done
- Copy aligned with real behavior
- `PLANS.md` updated

---

## M6 — State ownership contract document

### Goal
Create a hard source-of-truth document for core data entities.

### Tasks
- Add a document at `docs/state-ownership-contract.md`
- Document source of truth for profile, sessions, reps, progress, favorites, saved answers, entitlements, scenarios, onboarding state, and temporary audio
- Document write ownership, read priority, fallback behavior, and cross-device status
- Ensure terminology matches actual implementation

### Tests/checks
- Review doc against actual implementation
- Verify terminology matches code

### Acceptance criteria
- Engineers can answer where each core entity lives and who owns it
- Contract doc exists and matches current code

### Definition of done
- Doc added
- `PLANS.md` updated

---

## M7 — Favorites truth model cleanup

### Goal
Make favorites behavior and storage model unambiguous.

### Tasks
- Decide local-only vs synced based on current architecture and sprint constraints
- Align model, storage, and UI language
- Refactor as needed for clarity

### Tests/checks
- Verify favorites create, read, and persistence behavior
- Verify language matches truth model

### Acceptance criteria
- Favorites behavior is explicit and consistent in both code and UI

### Definition of done
- Favorites cleaned up
- `PLANS.md` updated

---

## M8 — Saved answers truth model cleanup

### Goal
Make saved answers behavior and persistence model unambiguous.

### Tasks
- Decide local-only vs synced based on current architecture and sprint constraints
- Align saved answer model, UI, and access behavior
- Refactor as needed for clarity

### Tests/checks
- Verify save, replay, and access behavior
- Verify copy matches truth model

### Acceptance criteria
- Saved answers behavior is explicit and consistent

### Definition of done
- Saved answers cleaned up
- `PLANS.md` updated

---

## M9 — Home next-action clarity improvements

### Goal
Make Home clearly answer: what should I do now?

### Tasks
- Audit Home hierarchy
- Improve recommendation prominence and CTA clarity
- Reduce ambiguity between full session, quick drill, browse, and recommendation
- Tighten relevant copy and layout behavior without broad redesign

### Tests/checks
- Verify Home to session launch paths
- Verify primary CTA clarity

### Acceptance criteria
- Home strongly directs the user to a logical next action
- Session launch options are easier to understand

### Definition of done
- Home improved
- `PLANS.md` updated

---

## M10 — Practice loop loading, feedback, and retry improvements

### Goal
Make the core record → analyze → feedback → retry loop clearer and more actionable.

### Tasks
- Improve recording instructions
- Improve loading and analyzing states
- Improve feedback readability
- Improve retry CTA clarity
- Tighten full-session rep progression

### Tests/checks
- Verify end-to-end practice loop behavior
- Verify feedback and retry states are readable and coherent

### Acceptance criteria
- Users can understand what happened and what to do next after each rep

### Definition of done
- Practice loop improved
- `PLANS.md` updated

---

## M11 — Completion-state momentum improvements

### Goal
Make session completion feel like progress, not a dead end.

### Tasks
- Improve completion summary
- Improve next-action CTAs
- Improve clarity around related scenario, quick drill, save best answer, and dismiss

### Tests/checks
- Verify completion state after session end
- Verify next actions are meaningful

### Acceptance criteria
- Completion state creates clear momentum toward the next action

### Definition of done
- Completion state improved
- `PLANS.md` updated

---

## M12 — Progress usefulness and empty-state improvements

### Goal
Make Progress behaviorally useful and motivating.

### Tasks
- Improve weekly summary usefulness
- Improve empty states
- Improve weak-spot and recent-win framing
- Improve recent sessions and saved answers value presentation
- Add or improve “practice next” guidance if grounded in existing data

### Tests/checks
- Verify populated and empty states
- Verify copy and insight quality remain honest

### Acceptance criteria
- Progress helps users understand improvement, weakness, and next practice direction

### Definition of done
- Progress improved
- `PLANS.md` updated

---

## M13 — Backend endpoint coverage improvements

### Goal
Add meaningful automated coverage for critical backend flows.

### Tasks
- Strengthen tests for:
  - `POST /startSession`
  - `POST /analyzeRep`
  - `POST /completeSession`
  - `POST /syncEntitlement`
- Cover happy paths and key edge cases
- Improve fixtures or helpers if needed for maintainability

### Tests/checks
- Run backend lint and tests

### Acceptance criteria
- Critical backend flows have stronger regression protection

### Definition of done
- Backend tests added
- `PLANS.md` updated

---

## M14 — iOS flow and UI regression coverage

### Goal
Add meaningful protection for critical client-side flows.

### Tasks
- Strengthen coverage for onboarding, auth, session entry, paywall trigger, settings, and progress hydration
- Add focused UI or integration tests where feasible
- Improve testability with small refactors only if necessary

### Tests/checks
- Run iOS tests available in project

### Acceptance criteria
- Highest-risk client flows are better protected against regression

### Definition of done
- iOS tests added
- `PLANS.md` updated
