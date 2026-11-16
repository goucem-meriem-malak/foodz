# Security checklist

Status labels: **Verified** (checked by running or scanning here), **Not verified** (written but not executed), **Outstanding** (planned, not built yet), **Not applicable**.
Nothing was compiled or run in the build environment (no Flutter, no Firebase emulator).

| Item | Status | Note |
|---|---|---|
| No secrets, keys, service accounts or personal email in the repo | Verified | Scanned all files at packaging. `.gitignore` covers env.json, service accounts, signing keys, push worker |
| `.gitignore` created before anything else, example file provided | Verified | `env.example.json` |
| Permissions enforced in Firestore rules, not in the UI | Not verified | Rules written. Not run |
| Rules tests (user A vs B, self-promotion, lock, courier access) | Not verified | `rules_tests/`. Written, not executed |
| Input validation in rules (names, phone, prices, sizes) | Not verified | Written, not executed |
| Order items content and prices | Outstanding | Rules check size and totals only. Server price check planned in round 2 |
| No self-promotion to admin or owner | Not verified | Rules and a test exist |
| Staff powers require a verified email | Not verified | Rules and a test exist |
| Customer contact details hidden from kitchen, shown to delivery only after claim | Not verified | Rules and tests exist |
| Spam orders limited | Not verified | One unconfirmed order per client (lock) and admin block |
| Authentication by a managed provider, no custom crypto | Verified | Firebase Authentication |
| Password reset, email verification | Not verified | Implemented, not run |
| Service account only in a server secret | Not verified | Supabase secret `FIREBASE_SERVICE_ACCOUNT`. Documented in SETUP |
| Push function checks identity and role, derives recipients from stored data | Not verified | Syntax checked only. Not deployed or run |
| Public client IDs vs secrets explained | Verified | `env.dart`, DOCUMENTATION |
| Push token removed on sign-out | Not verified | Implemented |
| HTTPS only | Not verified | Firebase and Supabase endpoints are HTTPS by default |
| Release build obfuscation, debug off | Not verified | Command in SETUP step 20 |
| Android backup disabled | Not verified | SETUP step 8 |
| Account deletion and data export | Outstanding | Profile and push tokens: implemented. Deleting the contact details of past orders arrives with the orders feature (round 2). The Privacy Policy already promises it |
| Dependencies audited and pinned | Outstanding | No network here. `pubspec.lock` is created by `flutter pub get` and must be committed |
| Terms and Privacy accepted and versioned | Not verified | Version stored on the user, asked again when `LegalVersions.current` changes |
| Terms and Privacy reviewed by a lawyer | Outstanding | Drafts, not legal advice |
| Payments, health, children, biometrics | Not applicable | Cash on delivery. No card data. Age 16+ stated in the Terms |
