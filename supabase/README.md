# Clothsy backend (Supabase)

Postgres, Auth, Storage and Edge Functions for the marketplace. Locally it
all runs in Docker Compose — see [docs/backend.md](../docs/backend.md).

| Folder | Contents |
|---|---|
| `migrations/` | Versioned SQL: tables, row level security, storage buckets, the order / payment / try-on functions, pg_cron jobs. Money is integer paise. |
| `functions/` | Edge Functions (Deno): `create-order`, `verify-payment`, `razorpay-webhook`, `refund`, `tryon-run`, `tryon-cleanup`, plus `main` (the local router). |
| `seed/` | `00_reference.sql` (coupons, PIN codes) and `10_catalog.generated.sql` (generated from the app's mock catalogue — do not edit). |
| `tests/database/` | pgTAP tests; `90_pricing_parity.generated.test.sql` checks the SQL money maths against Dart. |
| `docker/` | Compose helpers: gateway config, DB init, migrate and test runners. |

```bash
scripts/backend.sh up      # start + migrate + seed, writes apps/customer/config/dev.json
scripts/backend.sh test    # pgTAP + Deno
scripts/backend.sh e2e     # Phase 1 exit check through the gateway
scripts/backend.sh reset   # wipe and start again
```

Secrets (Razorpay key secret and webhook secret, FabricVTON key, SMS
provider) only ever live in the backend environment (`supabase/.env`
locally, `supabase secrets set …` on a hosted project) — never in the apps.
