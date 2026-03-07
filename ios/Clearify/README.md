# Clearify iOS App

## Setup
1. Install Xcode 15+ and XcodeGen (`brew install xcodegen`).
2. Use the Firebase plist for bundle ID `com.tuesday.clearify` in `ios/Clearify/Resources/GoogleService-Info.plist`.
3. Generate the project: `cd ios/Clearify && xcodegen generate`.
4. Open `Clearify.xcodeproj` in Xcode.
5. Set build setting `CLEARIFY_API_BASE_URL` to your Firebase HTTPS function base URL, for example:
   `https://us-central1-clearify-5414d.cloudfunctions.net/api`

## Notes
- Client uses Firebase Auth for identity and sends the ID token to backend endpoints.
- Audio files are uploaded to `tmp/{uid}/{sessionId}/rep-{n}.m4a` and deleted by backend after processing.
- Scenario fallback data is bundled in `Resources/scenarios.json` (170 prompts).
- The app links `FirebaseAnalyticsWithoutAdIdSupport` to avoid IDFA collection.
