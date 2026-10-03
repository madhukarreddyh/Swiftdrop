# SwiftDrop Rider — delivery partner app

Flutter app for SwiftDrop delivery partners (drivers) in Hyderabad.
Clean Rapido-style design: white, charcoal, emerald green.

## Connects to

The SwiftDrop backend (`../backend`, Laravel 12 API v1).

- **Base URL** is set at build time:
  `flutter build apk --debug --dart-define=API_BASE_URL=https://api.example.com`
- Default (no define): `http://10.0.2.2:8000` — the Android emulator's
  loopback to the developer machine. For a physical device on the same
  Wi-Fi, pass your machine's LAN IP instead.
- Auth uses Laravel Sanctum bearer tokens, persisted in secure storage.

## Run

```bash
cd apps/rider
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:8000
```

Backend must be running: `cd ../backend && php artisan serve`
(seeder creates zones + fare defaults; dev admin phone `9000000001`).

## Rider onboarding flow (v1)

1. Phone OTP login — new numbers auto-create a **customer** account.
2. The app detects non-rider accounts and shows the partner application
   (name + Aadhaar + licence + bike RC + bike number + bank).
3. `POST /rider/apply` flips the account to `role=rider`, status `pending`.
4. An admin approves via `POST /admin/riders/{id}/verify`.
5. The app shows Home; the partner taps **Go Online** to receive orders.

## Offer polling (v1)

FCM push is **not** wired yet. While online the app polls
`GET /rider/offers` every 15 seconds and shows the incoming-order card
with a 30-second countdown. Accept is atomic server-side — if another
partner took it first, the API returns `409 ALREADY_TAKEN` and the app
shows "Order taken by another partner."

## Honest v1 limitations

- **Foreground location only.** Pings stop if the app is backgrounded or
  killed by Android battery optimization. Background location + foreground
  service is planned for v2.
- **Maps use OpenStreetMap tiles** (free, no API key). Production should
  evaluate Ola Krutrim / MapMyIndia for cost.
- **Debug builds only.** Release signing (keystore) is not configured.
- **No FCM push** yet — polling (above).
- **No in-app chat** — Call uses the phone dialer with the customer's
  number from the order.

## Checks

```bash
flutter analyze   # must be clean
flutter test      # widget + unit tests
flutter build apk --debug
```
