# Connect Clearify To Real Firebase (Production)

## 1) Create Firebase project
1. Create project in Firebase Console.
2. Add iOS app with bundle id `com.tuesday.clearify`.
3. Download `GoogleService-Info.plist`.
4. Replace:
   - `ios/Clearify/Resources/GoogleService-Info.plist`

## 2) Enable Firebase products
1. Authentication
   - Enable Email/Password
   - Enable Sign in with Apple
2. Firestore Database (native mode)
3. Cloud Storage

## 3) Configure iOS app API URL
Set `CLEARIFY_API_BASE_URL` in Xcode Build Settings:
- Debug (production testing):
  - `https://us-central1-clearify-5414d.cloudfunctions.net/api`
- Release:
  - same production URL

When this URL is not localhost/127.0.0.1, the app will automatically use real Firebase services instead of local emulators.

## 4) Deploy backend
1. Authenticate CLI:
   - `npx firebase-tools login`
2. Select project:
   - `npx firebase-tools use <your-project-id>`
3. Build functions:
   - `cd backend/functions && npm install && npm run build`
4. Set OpenAI secret for functions:
   - `npx firebase-tools functions:secrets:set OPENAI_API_KEY`
5. Deploy:
   - `npx firebase-tools deploy --only functions,firestore:rules,storage`

## 5) Seed scenarios in real Firestore
From `backend/functions`:
- `export GCLOUD_PROJECT=<your-project-id>`
- `npm run seed:scenarios`

## 6) Verify account path
1. Launch app and create account via Email/Password.
2. Confirm user appears in Firebase Authentication users list.
3. Start a session.
4. Confirm documents are written under `users`, `sessions`, and `progress_daily`.
