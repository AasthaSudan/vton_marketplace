# Clothsy Marketplace

**See it on you.** A discovery-led, multi-brand fashion marketplace for India,
with Clothsy AI Try-On built into every product page.

This repo is a Dart/Flutter **workspace** containing every Clothsy surface:

```
apps/
├── customer/      # Customer app — Android, iOS & web (Flutter)
├── seller_web/    # Seller / Brand Panel (Flutter web)
└── admin_web/     # Admin & Operations Panel (Flutter web)
packages/
└── clothsy_core/  # Shared domain entities, money, theme tokens & widgets
supabase/          # Backend: migrations, Edge Functions, seed, tests
docker-compose.yml # Local backend (Postgres, Auth, REST, Storage, Functions)
docs/              # ROADMAP.md (status) and backend.md (local backend)
```

Where things stand and what is next: **[docs/ROADMAP.md](docs/ROADMAP.md)**.

---

## Getting started

```bash
git clone https://github.com/AasthaSudan/vton_marketplace.git
cd vton_marketplace
flutter pub get          # resolves the whole workspace
```

### Customer app

```bash
cd apps/customer
flutter run                         # mock flavor — no backend or keys needed
flutter run -t lib/main_dev.dart --dart-define-from-file=config/dev.json
```

| Flavor | Entry point | Backend |
|---|---|---|
| mock | `lib/main_mock.dart` (default `main.dart`) | In-memory mock repositories |
| dev | `lib/main_dev.dart` | Supabase dev (falls back to mock without a config) |
| staging | `lib/main_staging.dart` | Supabase staging — config required |
| prod | `lib/main_prod.dart` | Supabase prod — config required |

Copy `apps/customer/config/example.json` to `config/<flavor>.json` and fill in
the public client values. Real config files are git-ignored; secrets live only
in Supabase Edge Functions.

### Local backend (Docker)

```bash
scripts/backend.sh up       # Postgres, Auth, REST, Storage, Functions on :54321
cd apps/customer
flutter run -d chrome -t lib/main_dev.dart --dart-define-from-file=config/dev.json
```

Sign in with **99999 00001**, code **123456** (test numbers, no SMS sent).
Payments and Try-On use local mock providers until real keys are added.
Details: [docs/backend.md](docs/backend.md).

### Seller & Admin panels

```bash
cd apps/seller_web && flutter run -d chrome
cd apps/admin_web  && flutter run -d chrome
```

---

## Conventions

- **Brand:** Clothsy Violet `#5C25FC`, Deep Ink, Soft Lilac; Try-On Coral
  `#FF4F7B` is reserved for Clothsy AI. Poppins type scale. Use theme tokens
  (`context.colors`, `AppTypography`) — never raw hex in screens.
- **Money:** always integer **paise** (`₹1 = 100`). Format only at the UI edge
  with `CurrencyFormatter.format(paise)` → `₹1,499`.
- **Copy:** key microcopy (try-on consent, disclaimers, empty states) lives in
  `ClothsyCopy` so every app speaks with one voice.
- **Product images:** portrait 3:4 — size grids with `ProductCardGridDelegate`.
- **Architecture:** feature-first clean architecture; screens depend on
  repository interfaces in `clothsy_core`, implementations are swapped in
  Riverpod providers (mock ↔ Supabase).

---

## Tests

```bash
flutter analyze apps packages
(cd packages/clothsy_core && flutter test)
(cd apps/customer && flutter test)      # incl. 320px → 430px responsiveness matrix
(cd apps/seller_web && flutter test)
(cd apps/admin_web && flutter test)
```

```bash
scripts/backend.sh test                 # database (pgTAP) + Edge Functions (Deno), in Docker
scripts/backend.sh reset && scripts/backend.sh e2e   # Phase 1 flow end to end against the stack
```

CI (`.github/workflows/ci.yml`) runs formatting, analysis and all Flutter
tests, then builds the customer APK and both web panels;
`.github/workflows/backend.yml` runs the backend tests and the end-to-end
check in the same Docker stack.

---

## License

MIT © 2024 Aastha Sudan
