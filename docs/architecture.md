# Clearify Architecture (MVP)

## Client
- SwiftUI app orchestrates practice sessions and UI state.
- Firebase SDK used for auth, storage upload, Firestore reads.
- Backend endpoints called with Firebase ID token authorization.

## Server
- Firebase Cloud Functions (Express on `api` endpoint).
- Endpoints:
  - `POST /startSession`
  - `POST /analyzeRep`
  - `POST /completeSession`
- OpenAI integration is server-side only.

## Data
- Firestore stores users, sessions, reps, progress, usage, entitlements.
- Storage `tmp/{uid}/{sessionId}/rep-{n}.m4a` holds temporary audio only.
- Audio deleted after analysis.

## Scoring
- Four pillars each 0-25:
  - Structure
  - Clarity
  - Conciseness
  - Delivery
- Work Clarity Score is sum (0-100).

## Feedback Contract
- exactly one `primaryImprovement`
- exactly one `suggestedStructure`
- exactly one `rewrittenExample`
- exactly one `retryInstruction`
