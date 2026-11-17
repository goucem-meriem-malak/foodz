# Setup

## Change these before you push

| # | Where | What to put | Example | Secret? |
|---|---|---|---|---|
| 1 | `env.json` (new file, git-ignored) | Firebase keys from Project settings | `"FIREBASE_PROJECT_ID": "foodz-dz"` | No, public client IDs. File stays git-ignored anyway |
| 2 | Firebase console, Authentication | Turn on Email/Password and Google | | |
| 3 | Supabase secret `FIREBASE_SERVICE_ACCOUNT` | Service account JSON (step 17) | | **Yes**. Never in the repo |
| 4 | `android/key.properties` and `upload.jks` (git-ignored) | Android signing key (step 19) | | **Yes** |
| 5 | Firestore, document `users/<your uid>` | Set `role` to `owner` (step 16) | `owner` | |
| 6 | Firestore, document `settings/app` | Restaurant name, phone, email. The owner screen for this arrives in round 2 | `Dar Ennakhla` | |
| 7 | Git, `user.email` | Your GitHub no-reply address, not your real email (step 21) | | |

## Steps

1. Install: [Flutter](https://docs.flutter.dev/get-started/install), [Node.js 20+](https://nodejs.org), [Git](https://git-scm.com), [Android Studio](https://developer.android.com/studio) (for Android), Visual Studio 2022 with "Desktop development with C++" (for Windows).
2. Install the Firebase CLI:
   ```
   npm install -g firebase-tools
   ```
3. Open a terminal in this folder.
4. Create the platform folders (existing files are kept):
   ```
   flutter create --org com.gmm --project-name foodz --platforms=android,web,windows .
   ```
5. If `test/widget_test.dart` appeared, delete it.
6. Install packages (this also creates `pubspec.lock`, commit it to pin versions):
   ```
   flutter pub get
   ```
7. Android: open `android/app/build.gradle` (or `build.gradle.kts`) and set `minSdk` to `23`.
8. Android: open `android/app/src/main/AndroidManifest.xml`. Inside `<manifest>`, before `<application>`, add these two lines. In `<application>`, add `android:allowBackup="false"`.
   ```
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   ```
9. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com). Stay on the free Spark plan. Skip Google Analytics.
10. In Project settings, add an Android app with package name `com.gmm.foodz`, and a Web app named `Foodz`. The Web app is also used by Windows.
11. Authentication, Sign-in method: enable Email/Password and Google.
12. Firestore Database: create the database in production mode, location `eur3` or `europe-west1`.
13. Project settings, Cloud Messaging, Web Push certificates: generate a key pair. Copy it for the next step.
14. Create `env.json` and fill it in with the values from steps 10 and 13:
    ```
    cp env.example.json env.json
    ```
    (Windows: `copy env.example.json env.json`)
15. Link and deploy the rules and indexes:
    ```
    firebase login
    firebase use --add
    firebase deploy --only firestore:rules,firestore:indexes
    ```
16. Make yourself the owner. Run the app (step 18), sign up, verify your email, then in the Firebase console open Firestore, collection `users`, your document, and change `role` from `client` to `owner`. Restart the app.
17. Push server (so alerts arrive when the app is closed):
    1. Create a free project at [supabase.com](https://supabase.com).
    2. Log in and link (no install needed): `npx supabase login`, then `npx supabase link`. Pick an active project, not a paused one.
    3. Firebase console, Project settings, Service accounts, "Generate new private key". Save the file as `serviceAccount.json` in this folder. It is git-ignored.
    4. Store it as a secret. Easiest: Supabase dashboard, Edge Functions, Secrets, add `FIREBASE_SERVICE_ACCOUNT` and paste the whole file content as the value.
       Terminal alternative (PowerShell): `npx supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(Get-Content serviceAccount.json -Raw)"`, then type `y` when asked. If it cancels by itself, use the dashboard.
    5. Deploy: `npx supabase functions deploy notify-order`
    6. Delete `serviceAccount.json` from your computer.
    The app starts calling this function when orders are built (round 2). Windows has no push support, so staff on Windows see orders live while the app is open.
18. Create the icons, the native splash and the web push worker, then run:
    ```
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create
    node tool/gen_web_sw.mjs
    flutter run -d chrome --dart-define-from-file=env.json
    ```
    For Android use `-d` with your device name. For Windows use `-d windows`.
19. Run the tests:
    ```
    flutter test
    cd rules_tests
    npm install
    npm test
    ```
20. Build the release:
    - Android: create a key with `keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`, then follow [Flutter's signing guide](https://docs.flutter.dev/deployment/android#sign-the-app), then run
      `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env.json`
    - Web: `flutter build web --release --dart-define-from-file=env.json`, then `firebase deploy --only hosting`
    - Windows: `flutter build windows --release --dart-define-from-file=env.json`, then zip `build/windows/x64/runner/Release`
21. Before your first push, check that no secret is tracked. Both commands must print nothing:
    ```
    git init
    git add .
    git ls-files | grep -E "env.json|serviceAccount|google-services|\.jks|key.properties|firebase-messaging-sw.js"
    git grep -nE "AIza[0-9A-Za-z_-]{35}|BEGIN (RSA )?PRIVATE KEY"
    ```
22. First upload. On GitHub, open Settings, Emails, tick "Keep my email addresses private" and copy the address that ends with `@users.noreply.github.com`. Then:
    ```
    git config user.name "goucem-meriem-malak"
    git config user.email "PASTE-THE-NO-REPLY-ADDRESS-HERE"
    git commit -m "Foodz 1.0.0"
    git branch -M main
    git remote add origin https://github.com/goucem-meriem-malak/foodz.git
    git push -u origin main
    ```
23. Later updates:
    ```
    git status
    git add .
    git commit -m "Describe the change"
    git push
    git tag v1.0.0
    git push origin v1.0.0
    ```
    Then on GitHub: Releases, "Draft a new release", pick the tag.
24. GitHub "About" box.
    Description: `Food ordering and delivery for Algerian restaurants. Flutter + Firebase. Arabic, French, English, RTL. Roles: client, admin, owner, chef, delivery. Cash on delivery, push notifications.`
    Website: leave empty.
    Topics: `flutter`, `firebase`, `supabase`, `food-delivery`, `algeria`, `riverpod`, `rtl`, `arabic`, `firestore`, `fcm`

## If a key leaked

1. Rotate first. Firebase API key: restrict or regenerate it in Google Cloud console, Credentials. Service account: delete the key in Google Cloud console, create a new one, update the Supabase secret (step 17).
2. Then remove it from history with [git filter-repo](https://github.com/newren/git-filter-repo) and force-push.

## Common errors

- `Target of URI doesn't exist: .../app_localizations.dart`: run `flutter pub get`. The texts are generated.
- App shows "Setup is not finished": start it with `--dart-define-from-file=env.json`.
- `permission-denied` on sign-up: rules not deployed (step 15), or the phone number is not an Algerian mobile.
- No push on Android 13+: allow notifications for the app, and check step 8.
- Push stops on some phones (Xiaomi, Huawei, Oppo): turn off battery optimisation for the app. A force-stopped app cannot receive push on Android.
- Google sign-in popup blocked on web: add your site domain under Authentication, Settings, Authorized domains.
