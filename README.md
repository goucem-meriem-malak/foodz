<p align="center">
  <img src="docs/images/logo.png" alt="Foodz logo" width="128" />
</p>

<h1 align="center">Foodz</h1>

<p align="center">Algerian flavours, delivered to your door.<br/>Cash-on-delivery food ordering for restaurants, in Arabic, French and English.</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" />
  <img alt="Firebase" src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black" />
  <img alt="Supabase" src="https://img.shields.io/badge/Supabase-3ECF8E?logo=supabase&logoColor=white" />
  <img alt="Languages" src="https://img.shields.io/badge/languages-AR%20%7C%20FR%20%7C%20EN-DC0A22" />
  <img alt="License" src="https://img.shields.io/badge/license-all%20rights%20reserved-lightgrey" />
</p>

## Screenshots

| Launch | Sign in | Menu | Order tracking |
|---|---|---|---|
| `docs/images/screenshots/launch.png` | `docs/images/screenshots/sign-in.png` | `docs/images/screenshots/menu.png` | `docs/images/screenshots/tracking.png` |

| Kitchen | Delivery | Admin | Settings |
|---|---|---|---|
| `docs/images/screenshots/kitchen.png` | `docs/images/screenshots/delivery.png` | `docs/images/screenshots/admin.png` | `docs/images/screenshots/settings.png` |

## Features

Customers
- Menu by category with photos, dish options (size, extras), sold-out dishes, opening hours
- Cart, checkout with the "we will call you to confirm" notice, cash on delivery
- Dish photo upload and owner sales statistics
- Order tracking with live status, half-page PDF receipt (save or print)
- Guests can browse the menu; an account is needed to order

Restaurant team
- Admin and owner: live order board, call and confirm or reject with a reason, assign a delivery person, cancel
- Chef: kitchen screen, accept and choose a preparation time (the delivery person sees it), mark ready
- Delivery: upcoming orders with the ready time, take an order, see the address after taking it, mark delivered
- Owner: restaurant settings (fee, minimum, hours, switch to stop orders), menu, people and roles
- Push notifications for every step, also when the app is closed (Android and web)

Accounts and safety
- Email or Google sign-in, email verification, password reset, export and delete my data
- Terms of Use and Privacy Policy (AR / FR / EN), accepted again whenever the version changes
- Five roles with permissions enforced by Firestore rules
- Premium design system from the logo, light and dark, full right-to-left layout, animated launch screen

## Tech stack

| Part | Choice |
|---|---|
| App | Flutter (Android, web, Windows), Riverpod, go_router |
| Accounts and data | Firebase Authentication and Firestore, secured by rules |
| Push | Firebase Cloud Messaging, sent by a Supabase Edge Function |
| Images | Supabase Storage |
| Languages | Arabic, French, English (gen-l10n) |

## Project structure

```
lib/
  core/       theme, router, widgets, security, push, l10n helpers
  data/       models, repositories, providers
  features/   auth, menu, cart, orders, kitchen, delivery, admin, owner, settings, legal, splash
  l10n/       app_ar.arb, app_fr.arb, app_en.arb
assets/       brand (logo, icons), legal (terms and privacy texts)
docs/         DOCUMENTATION.md, SECURITY_CHECKLIST.md, legal copies
rules_tests/  Firestore rules tests
supabase/     notify-order push function
test/         unit tests
tool/         helper scripts
firestore.rules   all permissions live here
```

## Status

Round 1 of 3 is written but has not been run. Flutter is not available in the build environment, so nothing was compiled, analysed or executed. The palette contrast was calculated and passes WCAG AA. See `docs/SECURITY_CHECKLIST.md` for what is verified and what is not.

## Setup

Every step is in [SETUP.md](SETUP.md).

## License

All rights reserved. The source is public to be read, not to be reused. See [LICENSE](LICENSE).

## Credits

Logo by the project owner. Fonts: Cairo (Open Font License) through `google_fonts`.
