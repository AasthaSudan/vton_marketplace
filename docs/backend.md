# Local backend (Docker Compose)

Clothsy's backend is Supabase: Postgres with row level security, Auth
(phone OTP), Storage and Edge Functions. Locally a lean self-hosted subset
runs in Docker Compose, so nothing is installed on your machine except
Docker. The app talks to it exactly as it would to a hosted project.

```
            ┌──────────── gateway (nginx) :54321 ────────────┐
 app ──►    │ /auth/v1  /rest/v1  /storage/v1  /functions/v1 │
            └──┬────────────┬──────────┬───────────────┬─────┘
             auth        rest       storage        functions (Edge Runtime)
            (GoTrue)  (PostgREST)  (files)          create-order, verify-payment,
               └────────────┴──────────┴──── db ◄── razorpay-webhook, refund,
                                    (Postgres 17, :54322)   tryon-run, tryon-cleanup
```

## Requirements

* Docker Desktop running. The images take about **6.5 GB**; the first
  `scripts/backend.sh up` wants 10 GB free and stops early otherwise
  (`CLOTHSY_MIN_FREE_GB=7 scripts/backend.sh up` to lower the bar).
* 8 GB RAM is enough: Studio, Realtime, analytics, imgproxy and the pooler
  are left out.

## Everyday commands

```bash
scripts/backend.sh up       # start everything, apply migrations + seed,
                            # write apps/customer/config/dev.json
scripts/backend.sh test     # pgTAP database tests + Deno function tests
scripts/backend.sh e2e      # the Phase 1 exit check through the gateway:
                            # sign-in, Try-On, COD + prepaid orders, cancel,
                            # refund (run on a fresh stack: reset first)
scripts/backend.sh logs auth
scripts/backend.sh psql     # SQL shell (postgres)
scripts/backend.sh reset    # wipe all data and start fresh
scripts/backend.sh down
```

Run the app against it:

```bash
cd apps/customer
flutter run -d chrome -t lib/main_dev.dart --dart-define-from-file=config/dev.json
```

On an Android emulator use `http://10.0.2.2:54321` as `SUPABASE_URL` (or
`adb reverse tcp:54321 tcp:54321`).

## Signing in locally

Phone OTP works without an SMS provider: the numbers in `SMS_TEST_OTP`
(`supabase/.env`) always accept their code and never send a real SMS.

| Phone | Code |
|---|---|
| 99999 00001 | 123456 |
| 99999 00002 | 123456 |
| 99999 00003 | 123456 |

## Payments and Try-On without accounts

With no Razorpay or FabricVTON keys, the functions use **mock providers**,
allowed only while `ALLOW_MOCK_PROVIDERS=true` (local `.env` only):

* Online payment: the app's mock gateway pays with a `pay_mock_*` id, which
  only the mock payment provider accepts; the order is confirmed through
  the same verify-payment path a real payment uses. Cash on delivery works
  as in production.
* Try-On: previews "process" for a couple of polls and return the garment
  image, so the whole flow (credits, cache, polling, deletion) runs.

To use real providers, set `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`,
`RAZORPAY_WEBHOOK_SECRET`, `FABRICVTON_API_URL` and `FABRICVTON_API_KEY`
in `supabase/.env` (and `RAZORPAY_KEY_ID` in the app's config). Webhooks
and FabricVTON need a public URL, i.e. a hosted project or a tunnel.

## How data changes

* **Migrations** (`supabase/migrations/*.sql`) are applied in order by the
  `migrate` service and recorded in `supabase_migrations.schema_migrations`
  — the same table the Supabase CLI uses, so a hosted project can take over
  the history (`supabase db push`).
* **Seed** runs once on an empty database: `seed/00_reference.sql` (coupons,
  PIN codes) and `seed/10_catalog.generated.sql`, generated from the app's
  mock catalogue. After changing the mock, regenerate:
  ```bash
  cd apps/customer && flutter test --update-goldens test/tool/backend_fixtures_test.dart
  ```
* **Money maths** exists twice (Dart in the app, SQL in `place_order`). The
  same test generates `tests/database/90_pricing_parity.generated.test.sql`
  so CI fails if they ever disagree.

## Rules the backend enforces

* Money is integer paise; the server re-prices every order from the
  catalogue and refuses it (`PRICE_CHANGED`) if the total differs from what
  the shopper saw.
* Stock is held when an order is placed (15 minutes for online payment) and
  released when a payment fails, a hold expires (pg_cron) or a part is
  cancelled.
* A payment only counts once Clothsy confirms it (signature + gateway
  re-check, or the signed webhook). Confirming is idempotent; a late or
  duplicate payment is refunded automatically.
* Shoppers only see their own orders, addresses, photos and previews;
  sellers only their own part of an order; staff roles only what their
  role needs. Clients cannot write order or payment tables at all.
* Try-on photos need consent, live in a private bucket under the shopper's
  own folder, and are deleted after 30 days or as soon as the shopper asks.

## Scheduled jobs (pg_cron)

| Job | When | What |
|---|---|---|
| release-expired-reservations | every 5 min | cancels unpaid orders whose hold ran out |
| refund-sweep | every 5 min | sends queued refunds (refund function) |
| tryon-cleanup | hourly | deletes expired / removed try-on files |

The functions URL and service key they use are stored in
`private.settings` by the migrate step (`FUNCTIONS_URL`, `SERVICE_ROLE_KEY`).
