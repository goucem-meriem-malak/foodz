# Changelog

## 1.0.0 (build 3)

- Dish photo upload (Supabase function `upload-image`, admin and owner only, JPG/PNG/WebP up to 1.5 MB).
- Sales statistics screen for the owner.
- Build number shown in Settings.

## Earlier work in 1.0.0

Added in round 2
- Menu with categories, dishes, options and sold-out toggle; menu manager and dish editor for admin and owner.
- Cart and checkout (cash on delivery, "we will call you" notice), one unconfirmed order per customer.
- Orders: tracking, cancel while unconfirmed, half-page PDF receipt.
- Staff screens: order board with confirm and reject, kitchen, delivery, people and roles, restaurant settings with opening hours.
- Role-based navigation. Push request after every order change.
- Rules: new orders must match the owner's settings (shop open, delivery fee, minimum). Deleting an account erases the contact details of finished orders and is refused while an order is open.

## Round 1

Added
- Email/password and Google sign-in, email verification, password reset.
- Profile with name and Algerian phone number, edit, export and delete account.
- Terms of Use and Privacy Policy in Arabic, French and English, accepted at sign-up and again whenever the version changes.
- Firestore security rules for all roles (client, admin, owner, chef, delivery), with rules tests.
- Design system built from the F-fork logo (red and orange on near-black; light and dark, RTL), animated launch screen.
- Push notification registration on Android and web, and the `notify-order` server function.
- Settings: language, theme, restaurant contact, legal texts.

Next: polish and the remaining items listed in PROGRESS.md (round 3).
