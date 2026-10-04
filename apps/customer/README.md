# SwiftDrop Customer App

Parcel delivery for Hyderabad — send parcels across the city (like Rapido Parcels). **Parcel-only, no passenger rides.**

## Screens

| Screen | File | What it does |
|---|---|---|
| Splash | `lib/screens/splash_screen.dart` | Restores the saved token, routes to login or home |
| Login | `lib/screens/login_screen.dart` | 10-digit Indian mobile entry (6–9 start, backend rule) |
| OTP | `lib/screens/otp_screen.dart` | 4-digit code entry; **test mode**: shows `dev_code` returned by the backend when `APP_DEBUG=true` |
| Home (bottom nav) | `lib/screens/home_screen.dart` | Tabs: Home / Orders / Profile |
| Booking | `lib/screens/booking_screen.dart` | Map-first: OSM map, pickup/drop address fields, tap-to-place pins, parcel-type chips, UPI/Cash toggle, server fare quote, book |
| Tracking | `lib/screens/tracking_screen.dart` | Live status timeline, mini map, rider card with call button, cancel order, handover-OTP refresh (shows `dev_otp` in test mode); polls every 10 s |
| Orders | `lib/screens/orders_screen.dart` | Order history (paginated backend list) |
| Profile | `lib/screens/profile_screen.dart` | User card, Emergency SOS (dials 112 with confirmation), Help & Support, About, logout |
| Support | `lib/screens/support_screen.dart` | Raise a support ticket (`POST /support/tickets`) |

## Backend endpoints used (Laravel API v1)

- `POST /auth/otp/send` → `{message, dev_code?}` (dev_code only when `APP_DEBUG=true`)
- `POST /auth/otp/verify` → `{token, user}` (Sanctum token, secure storage)
- `POST /fare/quote` (public) → `{distance_km, fare_paise, breakdown[]}` — server-side only, ₹30 base / 3 km + ₹10/km
- `POST /orders` → creates order with server-computed fare, dispatches rider matching
- `GET /orders` → paginated own orders; `GET /orders/{id}` → order + rider relation
- `POST /orders/{id}/cancel` (before pickup); `POST /orders/{id}/otp/refresh` → `{dev_otp?}` in debug
- `POST /support/tickets`

## Build

```bash
export PATH=~/workspace/flutter_sdk/flutter/bin:$PATH
export JAVA_HOME=~/workspace/.sdk/jdk-17.0.9+9
export ANDROID_HOME=~/workspace/android-sdk
export GRADLE_USER_HOME=~/workspace/.gradle
export JAVA_TOOL_OPTIONS="-Djava.net.preferIPv4Stack=true"

flutter pub get
flutter analyze          # must be clean
flutter test             # must be green

# Point at the deployed backend:
flutter build apk --debug --split-per-abi \
  --dart-define=API_BASE_URL=https://your-backend.example.com
```

Default `API_BASE_URL` is `http://10.0.2.2:8000` (Android emulator → host localhost).
On a real phone you MUST pass `--dart-define=API_BASE_URL=<public backend URL>`,
otherwise login/booking will hang (that address doesn't exist on a phone).

## Known gaps (honest)

- No push notifications — tracking screen polls every 10 s.
- No address geocoding provider — addresses are free text; pins are placed by tapping the map (or "use my location" for pickup).
- OSM map tiles (no Google Maps key); foreground location only.
- Debug signing only; test-mode OTP display must be disabled (backend `APP_DEBUG=false`) before any real launch.
- Backend integration not tested live here (backend not deployed at build time).
