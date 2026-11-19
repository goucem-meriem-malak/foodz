# Progress

## Done
- Round 1: project, rules, accounts, design, launch screen, settings, legal texts, push registration and the `notify-order` function.
- Round 2: menu and dish options, menu manager and dish editor, cart, checkout, order tracking, PDF receipt, order board with confirm and reject, kitchen, delivery, people and roles, restaurant settings with opening hours, role-based navigation, rules that match orders to the owner's settings, contact details erased with the account.

## Not built yet
- Dish photo upload (photos are links for now).
- Server-side check of dish prices against the menu.
- Sales numbers (stats) for the owner.
- High-importance Android notification channel (pop-up banner).
- Real-device checks: the splash handoff, push when the app is closed, the receipt on a printer.

## Next step
Run the app (SETUP steps 1 to 18), do the "First use" section, then send me the first error or screen that looks wrong. Say "continue" for the items above.

## Known issues
- Nothing was compiled or run here (no Flutter). The first run may show small compile errors. Start with `flutter pub get`, `flutter analyze`, `flutter test`, and send me the output.
- `pubspec.lock` is not included. Package versions are ranges.
- Rules tests were never run. Run `firebase emulators:exec --only firestore "npm test"` inside `rules_tests` after `npm install`.
- Platform folders (android, web, windows) are created by `flutter create` (SETUP step 4).
- Legal texts describe the finished app. Re-read them before launch and have a lawyer review them.
