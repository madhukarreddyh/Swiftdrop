# SwiftDrop Backend — API v1

Laravel 12 JSON API powering the SwiftDrop parcel-delivery apps
(customer, rider, admin). **MySQL only** — never SQLite.

## What it does

- **Phone-OTP login** (Laravel Sanctum tokens, auto-creates customers)
- **Server-side fare quotes** — ₹30 base for first 3 km, then ₹10/km;
  money in **paise (integers)**, never floats; the client never sets prices
- **Zone enforcement** — pickup AND drop must be inside an ACTIVE zone
  (point-in-polygon), else `422 "We haven't reached this area yet"`
- **Order lifecycle** — requested → assigned → picked_up → delivered,
  with 4-digit **pickup & delivery OTPs** (10-min expiry, never in API responses)
- **Rider matching** — broadcasts to 3 nearest online approved riders;
  first accept wins (atomic); 60s expiry with auto re-dispatch
  (`orders:reassign-expired`, scheduled every minute)
- **Payments** — Razorpay-ready driver interface (fake driver in dev),
  signature-verified webhooks
- **Admin** — rider verification, fare settings (instant, no app update),
  zone drawing on/off, payouts, support tickets

## Setup

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
```

Edit `.env` (MySQL):

```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_DATABASE=swiftdrop
DB_USERNAME=swiftdrop
DB_PASSWORD=<your-password>
```

Then:

```bash
php artisan migrate --force
php artisan db:seed --force   # fare defaults, Kukatpally/KPHB/Moosapet zones, dev admin (phone 9000000001)
php artisan serve              # API at http://127.0.0.1:8000/api/v1
```

Scheduler (for order re-dispatch) — add to crontab:

```
* * * * * cd /path/to/backend && php artisan schedule:run >> /dev/null 2>&1
```

## Tests

Tests run against a **dedicated MySQL database** (`swiftdrop_test`, see
`phpunit.xml`) — never SQLite.

```bash
php artisan test
```

27 tests / 115 assertions, covering: fare math (incl. exactly-3km and 0km
edges, integer paise, 5/95 commission split), full order lifecycle with OTPs,
double-accept race (one winner), out-of-zone rejection, OTP rate limiting
(4/hour), and admin zone/fare controls.

## API quick reference

Base: `/api/v1`. Auth: `Authorization: Bearer <sanctum-token>`.

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/auth/otp/send` | – | Send login OTP (4/hour/phone) |
| POST | `/auth/otp/verify` | – | Verify OTP → token + user |
| POST | `/auth/logout` | user | Revoke token |
| POST | `/fare/quote` | – | Server-side fare estimate |
| POST | `/orders` | user | Create order (zone-checked, fare computed) |
| GET | `/orders`, `/orders/{id}` | user | List / view (owner, rider, admin) |
| POST | `/orders/{id}/cancel` | user | Cancel before pickup |
| POST | `/orders/{id}/otp/refresh` | customer | Regenerate pending handover OTP |
| POST | `/orders/{id}/accept` | rider | Atomic accept (first wins) |
| POST | `/orders/{id}/pickup` | rider | Verify pickup OTP |
| POST | `/orders/{id}/deliver` | rider | Verify delivery OTP |
| POST | `/rider/online` | rider | Go online/offline + location |
| POST | `/rider/location` | rider | Location ping (throttled) |
| POST | `/rider/documents` | rider | Submit KYC documents |
| GET | `/rider/earnings` | rider | Today/week/total + trips |
| GET | `/rider/orders` | rider | Assigned orders |
| GET | `/rider/profile` | rider | Rider profile |
| GET | `/admin/orders` | admin | All orders (filter by status) |
| GET | `/admin/riders` | admin | Rider list (filter by status) |
| POST | `/admin/riders/{id}/verify` | admin | Approve/reject rider |
| GET/PUT | `/admin/fare-settings` | admin | Fare config (instant) |
| GET/POST | `/admin/zones` | admin | List / create zones |
| PUT | `/admin/zones/{zone}` | admin | Update zone |
| POST | `/admin/payouts/generate` | admin | Weekly payouts |
| GET | `/admin/payouts` | admin | Payout list |
| POST | `/support/tickets` | user | Create ticket |
| GET | `/support/tickets` | user | List (own; admin sees all) |
| POST | `/support/tickets/{ticket}/reply` | user | Reply to ticket |
| POST | `/webhooks/razorpay` | – | Payment webhook (signature-verified) |

## Notes

- OTP codes are returned in API responses **only when `APP_DEBUG=true`**.
  They are never written to logs.
- Zone polygons in the seeder are rough rectangles — replace with precise
  boundaries before production.
- `services.payments.driver` = `fake` (dev) or `razorpay` (set
  `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` / webhook secret).
