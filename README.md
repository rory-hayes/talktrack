# Clearify MVP

Clearify is an iOS-first AI speaking coach focused on workplace communication and interview preparation.

## Repo Layout
- `ios/Clearify`: SwiftUI app scaffold (onboarding, home, practice loop, progress, paywall)
- `backend/functions`: Firebase Cloud Functions API (`startSession`, `analyzeRep`, `completeSession`)
- `backend/functions/scripts`: scenario library + seeding/export scripts
- `firestore.rules`, `storage.rules`: security rules

## MVP Features Implemented
- Daily loop with full sessions (3 reps) and quick drills (1 rep)
- Freemium limits: 3 full sessions/week + 1 quick drill/day
- AI response analysis pipeline (transcribe + rubric scoring + structured feedback)
- Work Clarity score (Structure, Clarity, Conciseness, Delivery)
- Streak/trend updates and progress aggregation
- 170-scenario library (50 interview, 80 workplace, 40 customer)

## Backend Setup
1. `cd backend/functions`
2. `npm install`
3. Configure env vars:
   - `OPENAI_API_KEY`
   - optional: `OPENAI_TRANSCRIBE_MODEL`, `OPENAI_FEEDBACK_MODEL`
4. Build and test:
   - `npm run lint`
   - `npm run test`
5. Deploy:
   - `firebase deploy --only functions,firestore:rules,storage`

## Firebase Modes
- Debug build defaults to local emulators (`127.0.0.1`) and enables Auth/Firestore/Storage emulator wiring automatically.
- Release build defaults to production API URL.
- To use production in Debug, set `CLEARIFY_API_BASE_URL` to your deployed Cloud Functions URL in Xcode Build Settings.

## Real Firebase Project Setup
1. Create a Firebase project in the Firebase Console.
2. Add an iOS app with bundle ID `com.tuesday.clearify`.
3. Download `GoogleService-Info.plist` and replace `ios/Clearify/Resources/GoogleService-Info.plist`.
4. In Firebase, enable:
   - Authentication: Email/Password + Apple
   - Firestore (native mode)
   - Storage
5. Deploy backend:
   - `npx firebase-tools login`
   - `npx firebase-tools use <your-project-id>`
   - `cd backend/functions && npm install && npm run build`
   - set `OPENAI_API_KEY` in functions runtime
   - `npx firebase-tools deploy --only functions,firestore:rules,storage`
6. Point app API to production:
   - `https://us-central1-<your-project-id>.cloudfunctions.net/api`
7. Seed scenarios:
   - `cd backend/functions && npm run seed:scenarios`
8. Full checklist:
   - [docs/firebase-production.md](/Users/rory/Documents/Clarify AI/docs/firebase-production.md)

## iOS Setup
1. Add Firebase app config file:
   - `ios/Clearify/Resources/GoogleService-Info.plist`
2. Generate Xcode project:
   - `cd ios/Clearify && xcodegen generate`
3. In Xcode set `CLEARIFY_API_BASE_URL` to your function URL, for example:
   - `https://us-central1-your-project.cloudfunctions.net/api`
4. Run on a physical device for microphone testing.

## Scenario Seeding
- Seed Firestore:
  - `cd backend/functions && npm run seed:scenarios`
- Export bundled scenarios to iOS resources:
  - `cd backend/functions && npm run export:scenarios`
