# AGENTS.md

## Purpose

This repository uses Codex as an implementation agent. Codex must operate with discipline, preserve product truth, avoid scope creep, and leave a clear execution trail.

The product is **Clearify**, an iOS-first AI speaking coach for workplace communication and interview preparation.

Core product loop:

1. User selects a realistic speaking scenario
2. User records a spoken answer
3. Backend transcribes and evaluates the answer
4. User receives one main coaching correction, one suggested structure, one rewritten example, and one retry instruction
5. Sessions contribute to streaks, progress, saved answers, and future recommendations

---

## Agent mission

Codex is here to:
- implement the next planned milestone
- respect the current architecture
- improve product quality without inventing new scope
- keep docs and execution history up to date
- leave the repo in a working, testable state

Codex is **not** here to:
- redesign the product without instruction
- introduce unrelated abstractions
- rewrite large systems unnecessarily
- ignore existing docs and implementation history
- make product decisions silently when ambiguity exists

---

## Required working process

For every task, Codex must follow this order:

1. Read `AGENTS.md`
2. Read `PLANS.md`
3. Read `SPRINT.md`
4. Inspect the repo areas relevant to the current milestone
5. Summarize:
   - current behavior
   - likely files to change
   - risks
   - implementation plan
6. Implement only the current milestone scope
7. Run relevant tests/checks
8. Update `PLANS.md`
9. Report:
   - what changed
   - tests run
   - risks / follow-ups

Do not skip the planning step.

---

## Repository rules

### 1. Respect architecture
Preserve the current architecture unless a change is clearly justified by the current milestone.

Current architecture:
- iOS client: SwiftUI under `ios/Clearify`
- Backend: Firebase Cloud Functions Express app under `backend/functions`
- Auth: Firebase Auth
- Database: Firestore
- Storage: Firebase Storage
- Billing: StoreKit

### 2. Prefer minimal safe changes
Make the smallest correct change that solves the milestone.

### 3. No scope creep
- Do not implement future milestones early
- Do not do unrelated “while I’m here” improvements
- Do not add features unless explicitly required by the milestone

### 4. Product truth over appearance
If UI copy, behavior, and persistence disagree, fix the truth mismatch.
Never leave misleading labels, false promises, or dead controls.

### 5. User-visible quality matters
Anything user-facing must feel production-grade:
- polished copy
- no raw internal error strings
- no debug language
- no dead taps
- no contradictory naming

### 6. Do not invent hidden behavior
If behavior is not implemented, do not imply that it is.

### 7. Update execution history
Every milestone completion must update `PLANS.md`.

---

## Documentation rules

### PLANS.md
This is the execution log and current status board.
It must always reflect:
- what was completed
- what is in progress
- what is blocked
- what is next

### SPRINT.md
This is the source of milestone truth.
Codex must only execute the next open milestone unless explicitly told otherwise.

### If implementation changes product behavior
Update relevant docs.

---

## Implementation standards

### Code changes must be:
- bounded
- readable
- testable
- consistent with existing project style

### Refactors must be:
- justified by the milestone
- minimal
- low-risk

### Copy changes must be:
- plain
- accurate
- user-readable
- non-technical

---

## Testing standards

For every milestone, run the most relevant checks available.

Examples:
- iOS build/tests for SwiftUI changes
- backend lint/tests for function changes
- targeted test coverage where logic is added or changed

If tests cannot be run, state exactly why.

Do not claim confidence without verification.

---

## Milestone execution rules

Codex must:
- execute one milestone at a time
- mark it complete only if all acceptance criteria are satisfied
- update `PLANS.md` before stopping

Codex must not:
- start multiple milestones in one run unless explicitly instructed
- mark partial work as complete
- skip definitions of done

---

## Required output format for each run

At the end of each run, provide:

1. Milestone executed
2. Summary of what changed
3. Files changed
4. Tests/checks run
5. Result against acceptance criteria
6. Any follow-up risks or blocked items
7. Confirmation that `PLANS.md` was updated

---

## Escalation rules

If a milestone is ambiguous, Codex should:
- choose the safest narrow interpretation
- document the ambiguity in `PLANS.md`
- avoid broad speculative changes

If a blocker prevents completion, Codex should:
- stop
- document the blocker clearly
- leave partial work in a coherent state
- update `PLANS.md`

---

## Success standard

Success is not “some code was written.”

Success means:
- the milestone was implemented correctly
- the repo remains coherent
- tests were run where possible
- docs were updated
- the next person can understand what happened
