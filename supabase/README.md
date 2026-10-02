# Clothsy backend (Supabase)

Postgres, Auth, Storage and Edge Functions for the marketplace. Populated in
**Phase 1** of the implementation plan.

| Folder | Contents |
|---|---|
| `migrations/` | Versioned SQL: tables, RLS policies, Postgres functions (money in integer paise) |
| `functions/` | Edge Functions: `create-order`, `verify-payment`, `razorpay-webhook`, `refund`, `tryon-run`, … |
| `seed.sql` | Demo sellers and catalogue for local development |

```bash
brew install supabase/tap/supabase
supabase init      # creates config.toml (first time only)
supabase start     # local stack on Docker
supabase db reset  # apply migrations + seed
```

Secrets (Razorpay key secret, FabricVTON API key, SMS provider) are set with
`supabase secrets set …` and are **never** shipped in the apps.
