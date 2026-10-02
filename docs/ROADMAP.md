# Clothsy Marketplace — Roadmap & status

Source of truth for *what* to build: the **Product & Brand Blueprint v1.0**
(Oct 2026). This file tracks *where we are*. Update it with every feature
commit.

Legend: ✅ done · 🟡 partly done / mock only · ⏳ written, not yet verified ·
⬜ not started · 🔑 needs an account or business decision

## Phases

| Phase | Scope | Status |
|---|---|---|
| **P0** Restructure & rebrand | Workspace, brand, ₹/paise, nav, flavors, panel shells, CI | ✅ |
| **P1** Customer core + Try-On + payments | Auth, catalogue, search, PDP, bag, checkout, orders, Try-On, Supabase backend | ✅ on the local Docker backend · real providers 🔑 |
| **P2** Seller Panel | Onboarding/KYC, storefront, products & stock, fulfilment, payouts | ⬜ (shell only) |
| **P3** Admin + returns | Roles, moderation, orders & money, returns/refunds/disputes, CMS | ⬜ (shell only) |
| **P4** Growth | Clothsy Coins, referrals, follows & drops, notifications, personalised feeds | ⬜ |
| **P5** Clothsy AI suite | AI search, stylist, visual search, size help, complete the look | ⬜ |
| **P6** Website, hardening, launch | SEO site, legal pages, security, load tests, beta → launch | ⬜ |

## Phase 1 in detail

### Customer app (runs fully on mocks: `flutter run`)

| Area (blueprint §) | Status | Notes |
|---|---|---|
| Phone OTP sign-in, guest browsing (§24) | ✅ | 6-digit OTP, friendly errors, sign-in guard on checkout / orders / addresses / try-on history |
| Google / Apple sign-in | 🔑 | Buttons say "coming soon" against a real backend |
| Style onboarding (§24) | ✅ | Name, categories, looks, brands, budget — all skippable, editable from Profile |
| Home, Explore, brands (§25) | ✅ | Filters (size, price, brand), paging, brand directory & storefronts |
| Search (§25) | ✅ | Debounced, recent + trending, typo-tolerant on the backend |
| Product page (§26) | ✅ | PIN → delivery date, COD, seller return window, size chart by category, sold-out sizes |
| "Coins you earn" on PDP | 🔑 | Waits for Coins rules (P4) |
| Multi-seller bag (§27) | ✅ | Grouped by brand, per-shipment delivery, coupons, saved across restarts |
| Checkout & payment (§28) | ✅ | Per-brand delivery dates, COD where allowed (cap is a 🔑 placeholder ₹10,000), create → pay → confirm |
| Orders & tracking (§29) | ✅ | One order, many sellers; cancel one part or all; refund messaging |
| Invoices | ⬜ | P2 (per-seller GST invoices) |
| Clothsy AI Try-On (§35) | ✅ | Own photo with consent, colour confirm, regenerate, size → bag, credits, deletion |
| Settings & privacy (§32) | ✅ | Appearance, try-on photo controls; policies 🔑 (legal review) |

### Backend (local Docker Compose stack — `scripts/backend.sh`)

| Piece | Status | Notes |
|---|---|---|
| Docker Compose stack (Postgres, Auth, REST, Storage, Functions, gateway) | ✅ | `scripts/backend.sh up`; about 6.5 GB of images |
| Schema + row level security (11 migrations) | ✅ | Sellers, catalogue, stock ledger, addresses, coupons, orders, payments, refunds, try-on, storage, cron |
| Order functions (`place_order`, confirm / fail / cancel, refunds, expiry) | ✅ | Server pricing, stock holds, idempotency, late/duplicate payment refunds |
| Edge Functions (create-order, verify-payment, razorpay-webhook, refund, tryon-run, tryon-cleanup) | ✅ | Mock providers locally; Razorpay / FabricVTON adapters ready |
| Tests | ✅ | pgTAP (8 files, 173 assertions), Deno (31), end-to-end exit check (49 checks); `scripts/backend.sh test` / `e2e`, and in CI |
| App ↔ backend wiring (Supabase repositories, Razorpay gateway) | ✅ | Also run in the browser against the stack: guest browsing, test-OTP sign-in, onboarding saved, prepaid checkout with FIRST15 → paid |
| Real Razorpay payments + webhooks | 🔑 | Test keys + a public URL |
| Real FabricVTON try-on | 🔑 | API key + docs; adapter has `TODO(fabricvton)` markers |
| Real SMS OTP | 🔑 | DLT-registered SMS provider |
| Hosted Supabase projects (dev / staging / prod) | 🔑 | |

### Exit check for Phase 1 ✅

Passes on the local stack (`scripts/backend.sh reset && scripts/backend.sh e2e`): test-OTP sign-in → style onboarding saved → search
"blazr" finds the blazer → PIN check → try on with your own photo → a
two-brand bag with LUXURY20 → COD order → prepaid order goes pending →
paid → cancel one brand's part → refund queued for exactly that part and
stock restored.

## Decisions waiting on the business 🔑

* COD limit (placeholder ₹10,000) and COD-abuse rules
* Commission policy, return policy, Coins rules
* Payment, courier (Shiprocket recommended) and messaging partners
* Legal pages: terms, privacy, refund, return, cancellation, shipping, seller terms
