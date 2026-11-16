# Progress

## Done (round 1)
- Project config, `.gitignore`, license, brand assets, icon and splash config
- Firestore rules for all roles and the order state machine, plus rules tests
- Auth (email, Google), email verification, profile gate, terms gate, blocked screen
- Design system, three languages with RTL, animated splash, settings, legal texts (AR/FR/EN)
- Push client (token registration) and the `notify-order` server function
- Unit tests, README, SETUP, DOCUMENTATION, SECURITY_CHECKLIST

## Remaining
Round 2: menu (categories, dishes, options, sold out), restaurant settings screen with opening hours (rules and model need an `hours` field), cart and checkout with the "we will call you to confirm" notice, order tracking, admin, chef and delivery screens, calling `notify-order` after every order change, Supabase image upload function, deleting order contact details on account deletion, server price check.
Round 3: PDF half-page receipt (save and print), owner tools (staff roles, stats), polish, final scan.

## Next step
Say "continue" to start round 2.

## Known issues
- Nothing was compiled or run. First run may need small fixes. Start with `flutter pub get`, `flutter analyze`, `flutter test`.
- `pubspec.lock` is not included. Package versions are ranges.
- Platform folders (android, web, windows) are created by `flutter create` (SETUP step 4).
- Legal texts describe the finished app (orders, map position). Re-read them after round 3.
- Android push uses the default Firebase channel: sound and notification shade, no pop-up banner. A high-importance channel is added in round 2 together with the order screens.
- Rules and rules tests were never run. Run `firebase emulators:exec --only firestore "npm test"` inside `rules_tests` after `npm install`.
