# Foodz documentation

## Architecture

One Flutter codebase (Android, web, Windows). Firebase Authentication identifies users. Firestore stores data and is the only place that decides who may do what (`firestore.rules`). Hidden buttons are never security.

```
Flutter app  ──►  Firestore (rules enforce roles)
     │
     └─ after an order changes ──►  Supabase Edge Function notify-order
                                         │ verifies the Firebase ID token
                                         │ reads the order with a service account
                                         └──►  Firebase Cloud Messaging  ──►  phones / browsers
```

Code layers: `core/` (theme, router, widgets, services), `data/` (models, repositories, Riverpod providers), `features/` (screens), `l10n/` (all text). Colours, spacing, radii and motion come from `core/theme/tokens.dart` only.

Configuration is passed at build time with `--dart-define-from-file=env.json`. The Firebase values in it are public client identifiers. The only real secret, the service account, lives in a Supabase secret.

## Data model

| Path | Fields | Notes |
|---|---|---|
| `users/{uid}` | name, phone, email, role, blocked, locale, termsVersion, termsAcceptedAt, createdAt | Role and blocked are never writable by the user |
| `users/{uid}/devices/{token}` | platform, updatedAt | Push tokens. Removed at sign-out |
| `settings/app` | restaurantName, deliveryFee, minOrder, defaultPrepMinutes, acceptingOrders, contactPhone, contactEmail | Public read, owner write |
| `categories/{id}`, `dishes/{id}` | localized names (ar/fr/en), price (DZD, integer), options, available | Public read, admin write |
| `orders/{id}` | clientUid, code, status, items, subtotal, deliveryFee, total, area, note, timestamps, courierUid, prepMinutes, rejectReason | No contact details here |
| `orders/{id}/private/contact` | name, phone, address, lat, lng | Kept apart on purpose |
| `placedLocks/{uid}` | orderId | One unconfirmed order per client |
| `pushLog/{orderId_status}` | createdAt | Server only. Makes each push fire once |

## Permission matrix

| Action | Guest | Client | Chef | Delivery | Admin | Owner |
|---|---|---|---|---|---|---|
| Read menu and settings | yes | yes | yes | yes | yes | yes |
| Edit menu | | | | | yes | yes |
| Edit restaurant settings | | | | | | yes |
| Place order (one unconfirmed at a time) | | yes | | | | |
| Cancel own order while "placed" | | yes | | | | |
| Confirm or reject order | | | | | yes | yes |
| Read orders in confirmed, preparing, ready | | own | yes | yes | all | all |
| See customer contact details | | own | never | only after claiming | yes | yes |
| Accept, set prep time, mark ready | | | yes | | override | override |
| Claim, mark delivered | | | | yes | override | override |
| Block a client | | | | | yes | yes |
| Change a user's role | | | | | | yes (never to owner) |
| Staff powers need a verified email | | | yes | yes | yes | yes |

The first owner is set by hand in the Firebase console. A user cannot promote themselves, and nobody can create a second owner from the app.

## Order flow

`placed` → `confirmed` (admin, after the phone call) → `preparing` (chef picks 10, 20 or 30 min) → `ready` (chef) → `out_for_delivery` (delivery person claims, admin can override) → `delivered`.
Also `placed` → `rejected` (admin, with a reason) or `cancelled` (client). Admin can cancel any order before delivery.
Delivery people see an order from `confirmed`, with the chef's time once it is known, so they can get ready. Contact details appear only after they claim it.

## Push notifications (also when the app is closed)

- The app saves its FCM token under `users/{uid}/devices`.
- After each order change the app calls `notify-order` with `{orderId}` and the user's Firebase ID token.
- The function checks the token, checks the caller is the order's client or staff, then decides recipients from the stored status (new order to admins; confirmed to client, kitchen, delivery; ready to delivery; on the way and delivered to client; and so on). Each status is announced once.
- Messages are sent in each user's own language (ar/fr/en).
- Android and web only. Windows has no Firebase Messaging, so staff on Windows see live updates while the app is open.
- Android limits: a force-stopped app does not get push, and some makers (Xiaomi, Huawei, Oppo) kill background apps unless battery optimisation is turned off.
- Heads-up banners and sound follow the phone's notification settings for the app.

## Design decisions

- Palette from the logo: signal-red primary (#DC0A22), flame-orange accent (#FD610E), near-black dark theme, warm neutrals. Every text pair was calculated against WCAG AA (4.5:1) and passes in light and dark. `test/palette_contrast_test.dart` repeats the check.
- Airy, soft style: 16 to 20 px radii, hairline borders, tonal surfaces, decelerating motion (cubic-bezier 0.16, 1, 0.3, 1), reduced-motion respected.
- Fonts: Cairo (Arabic and Latin) through `google_fonts`. Negative letter-spacing is applied to Latin only.
- Spacing is a scale of multiples of 4. Touch targets are at least 48 px.
- Splash: the native splash and the Flutter overlay share the same background colour and a 160 dp logo, so there is no jump. The logo rises from the bottom with a spring settle and a light sweep, "Foodz" fades in 150 ms later, then a circular reveal opens the app. About 1.1 s in total, and it ends as soon as the session is known.
- Menu images go to Supabase Storage as you asked. Firestore roles cannot be read by Supabase, so uploads will go through a function that checks the role first (round 2).

## Known limits

- Firestore rules check the shape and size of an order but cannot recalculate prices from the menu. A modified client could send wrong prices. Staff confirm every order by phone. Round 2 adds a server-side price check in the push function and a "price differs from menu" flag on the admin screen.
- Free tiers can change. Firestore Spark (about 50,000 reads and 20,000 writes per day) and Supabase free limits (500,000 function calls a month, projects pause after a week of no use) are from memory and not verified: check them before quoting a client. Supabase free has no backups. Firestore has no automatic backup on the free plan. Put this in the handover.
- Costs. Developer: none. Client: none while inside the free tiers. Recurring risk: a paid plan is needed if traffic outgrows them.
