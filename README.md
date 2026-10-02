# Clothsy Marketplace

> **See it on you.** A discovery-led, multi-brand fashion marketplace with AI Virtual Try-On built into every product page.

---

## Architecture

```
                         ┌────────────────────────────────────────────────────────┐
                         │                    Clothsy Clients                     │
                         │ Customer App (iOS/Android/Web) · Seller Web · Admin Web│
                         └───────────────────────────┬────────────────────────────┘
                                                     │
                                    Shared Core (`packages/clothsy_core`)
                                   Domain · Money · Theme Tokens · Widgets
                                                     │
                         ┌───────────────────────────┴────────────────────────────┐
                         │               Supabase Gateway (:54321)                │
                         └──────┬──────────────┬──────────────┬────────────┬──────┘
                                │              │              │            │
                          /auth/v1       /rest/v1      /storage/v1   /functions/v1
                                │              │              │            │
                         ┌──────▼──────┐┌──────▼──────┐┌──────▼──────┐┌────▼─────────────┐
                         │ Auth/GoTrue ││  PostgREST  ││   Storage   ││  Edge Functions  │
                         │ (Phone OTP) ││  (Data API) ││   (Files)   ││  (Deno Runtime)  │
                         └──────┬──────┘└──────┬──────┘└──────┬──────┘└────┬─────────────┘
                                │              │              │            │
                                └──────────────┼──────────────┼────────────┘
                                               ▼              ▼
                         ┌────────────────────────────────────────────────────────┐
                         │              PostgreSQL 17 Database (:54322)           │
                         │   Row Level Security (RLS) · Real-time Stock Ledger    │
                         │   Money Pricing Parity (SQL & Dart) · pg_cron Jobs     │
                         └─────────────────────────────┬──────────────────────────┘
                                                       │
                                         External / Mock Providers
                                  Razorpay (Payments) · FabricVTON (Try-On)
```

---

## Workspace Layout

```
apps/
├── customer/      # Customer mobile & web app (Flutter)
├── seller_web/    # Seller & Brand Management Portal (Flutter web)
└── admin_web/     # Operations & Moderation Panel (Flutter web)
packages/
└── clothsy_core/  # Shared domain entities, theme tokens, money & reusable widgets
supabase/          # Backend: migrations, Edge Functions, seed data & pgTAP tests
scripts/           # Automation scripts (backend launcher, test runners, e2e suite)
docker-compose.yml # Self-hosted local backend stack
```

---

## Core Conventions

- **Design System:** Clothsy Violet (`#5C25FC`), Deep Ink, Soft Lilac; Try-On Coral (`#FF4F7B`) reserved exclusively for Clothsy AI features. Powered by Poppins typography and design tokens (`context.colors`, `AppTypography`).
- **Currency & Money:** Always handled as integer **paise** (`₹1 = 100`) across both frontend (Dart) and backend (Postgres SQL) to prevent rounding discrepancies. Formatted exclusively at the UI edge with `CurrencyFormatter.format(paise)`.
- **Clean Architecture:** Feature-first modular architecture; presentation layers depend on abstract repository interfaces in `clothsy_core`. Implementations are easily swapped between in-memory mock repositories and real Supabase backends via Riverpod.

---

## Getting Started

### 1. Prerequisites & Dependencies

```bash
git clone git@github.com:fabricVTON/vton_marketplace.git
cd vton_marketplace
flutter pub get          # Resolves dependencies across the entire workspace
```

### 2. Running Customer App

```bash
cd apps/customer

# Option A: Zero-config Mock Mode (In-memory repositories, no keys or backend required)
flutter run

# Option B: Connected to Local or Remote Backend
flutter run -t lib/main_dev.dart --dart-define-from-file=config/dev.json
```

| Flavor | Entrypoint | Backend Behavior |
|---|---|---|
| **mock** | `lib/main.dart` / `lib/main_mock.dart` | In-memory mock repositories; runs anywhere instantly |
| **dev** | `lib/main_dev.dart` | Supabase dev (falls back to mock if unconfigured) |
| **staging**| `lib/main_staging.dart` | Supabase staging environment |
| **prod** | `lib/main_prod.dart` | Production environment |

### 3. Running Seller & Admin Panels

```bash
cd apps/seller_web && flutter run -d chrome
cd apps/admin_web  && flutter run -d chrome
```

---

## Local Backend (Docker)

Clothsy provides a self-hosted Supabase environment (Postgres, GoTrue Auth, PostgREST, Storage, and Edge Functions) via Docker Compose.

```bash
scripts/backend.sh up       # Starts stack on :54321, runs migrations & writes dev.json
scripts/backend.sh test     # Runs pgTAP database tests & Deno function tests
scripts/backend.sh e2e      # End-to-end integration check (auth, try-on, orders, refunds)
scripts/backend.sh down     # Stops containers
```

### Local Test Credentials

Phone OTP operates locally without third-party SMS providers:

| Phone Number | Verification Code |
|---|---|
| `99999 00001` | `123456` |
| `99999 00002` | `123456` |
| `99999 00003` | `123456` |

Payments and Try-On automatically fall back to local mock providers when production API keys are absent.

---

## Verification & Testing

```bash
# Code Analysis
flutter analyze apps packages

# Unit & Widget Tests
(cd packages/clothsy_core && flutter test)
(cd apps/customer && flutter test)
(cd apps/seller_web && flutter test)
(cd apps/admin_web && flutter test)

# Backend Integration Suite
scripts/backend.sh test
scripts/backend.sh reset && scripts/backend.sh e2e
```

---

## License

MIT © 2024–2026 Aastha Sudan
