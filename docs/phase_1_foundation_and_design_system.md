# Clothsy Shop App — Phase 1: Foundation and Design System

## Goal
Set up a production-grade Flutter project, lock the brand design system (Clothsy AI colours + reference UI style), and build the reusable component library every later screen will use. No feature screens yet beyond a component gallery.

## Product Summary
- Fashion e-commerce app for iOS and Android.
- Visual language: editorial serif headlines, lots of whitespace, rounded cards, lilac accents on a warm cream base (matches clothsyai.fabricvton.com).
- Differentiator: built-in AI virtual try-on (Clothsy AI) on every product page — shipped in Phase 4, but the architecture reserves space for it now.

## Tech Stack (decided)
| Layer | Choice | Why |
|---|---|---|
| Framework | Flutter (latest stable), Dart 3 | Single codebase, iOS + Android |
| State management | Riverpod (with code generation) | Testable, compile-safe, scales well |
| Routing | go_router | Deep links, nested tab navigation, auth redirects |
| Models | freezed + json_serializable | Immutable models, union states |
| Networking | Dio + interceptors | Auth headers, retries, logging |
| Commerce backend | Shopify Storefront API (GraphQL) | Clothsy already lives on Shopify; products, cart, checkout for free |
| Local storage | Hive or Isar for cache, flutter_secure_storage for tokens | Fast offline cache, secure secrets |
| Images | cached_network_image | Caching + placeholders |
| Fonts | google_fonts (bundled at build) | Serif display + clean sans body |
| Analytics / push | Firebase (Analytics, Crashlytics, Messaging) | Standard, free tier |

Keep the backend behind a repository interface so Shopify can be swapped for a custom backend (e.g. Supabase or FastAPI) later without touching UI.

## Architecture
Feature-first clean architecture. Each feature folder contains three layers:
- data: API clients, DTOs, repository implementations
- domain: entities, repository contracts, use cases
- presentation: screens, widgets, Riverpod providers/controllers

Top-level folders:
- core: theme, constants, network client, error types, utilities, router
- shared: design-system widgets used across features
- features: onboarding, auth, home, catalog, product, search, cart, checkout, orders, wishlist, profile, tryon
- l10n: localisation files (English first, Hindi-ready)

Rules:
- UI never calls the API directly; it goes through providers to repositories.
- Every async screen has four states: loading (skeleton), data, empty, error (with retry).
- No hardcoded colours, sizes or strings inside widgets — everything comes from theme tokens and l10n.

## Design Tokens

### Colours
Only the background is confirmed from the site's theme colour. The rest are matched to the reference UI and the site's lilac imagery — confirm against the site CSS or brand kit before freezing.

| Token | Hex | Use |
|---|---|---|
| background | #FAF7F3 (confirmed) | App background |
| surface | #FFFFFF | Cards, sheets |
| surfaceMuted | #F2EDF7 | Chips, category circles, offer banners |
| primary | #2B1E3F | Buttons, selected states, hero banner, icons |
| onPrimary | #FFFFFF | Text on primary |
| accent | #B9A6E0 | Highlights, badges, active dots |
| accentSoft | #E7DFF6 | Discount pill background, selected size ring |
| textPrimary | #1A1523 | Headlines, prices |
| textSecondary | #6E6878 | Descriptions, captions |
| strikethrough | #A39FAB | Original price |
| border | #E6E1EA | Outlined buttons, dividers |
| success | #2E7D5B | Order confirmed, in stock |
| error | #C2413B | Validation, out of stock |
| rating | #F2B63C | Stars |

Dark mode: define the same token names with dark values now; ship light mode first.

### Typography
- Display / headlines: elegant high-contrast serif (Playfair Display or DM Serif Display) — onboarding title, section headers, product name on PDP.
- Body / UI: clean sans (Inter or DM Sans) — everything else.
- Scale: Display 40, H1 28, H2 22, H3 18, Body 15, Caption 13, Label 12. Line heights 1.2 for display, 1.45 for body.

### Spacing, radius, elevation
- Spacing scale: 4, 8, 12, 16, 20, 24, 32, 48.
- Screen side padding: 20.
- Radius: 12 for small cards/chips, 20 for product cards and banners, 28 for pill buttons, full circle for category icons and colour swatches.
- Shadows: very soft and low (the reference is almost flat). Prefer tonal surfaces over heavy shadows.

### Motion
- Standard duration 250ms, ease-out curve.
- Hero transition for product image from card to PDP.
- Subtle scale-down on tap for cards and buttons.

## Component Library (build all in Phase 1)
- Primary button (filled plum, pill) and secondary button (outlined, pill), with loading and disabled states.
- Icon button (circular, used for back, wishlist, cart, arrow-forward).
- Cart icon with count badge.
- Product card: image, discount badge, wishlist heart, name, price, optional strike price.
- Category chip: circular icon tile plus label, selected state in primary.
- Promo banner: dark plum card with serif headline, subtitle, CTA button, image on right, page dots.
- Offer strip: soft lilac card with icon, title, subtitle, arrow button.
- Size selector (circular chips) and colour swatch selector (circles with selection ring).
- Price row: current price, strikethrough price, discount pill.
- Rating row: star, value, review count.
- Quantity stepper.
- Section header with "See All" action.
- Search bar, text field, OTP field.
- Bottom navigation bar (Home, Explore, Try-On, Wishlist, Profile).
- Skeleton loaders for card, list and PDP.
- Empty-state and error-state widgets with illustration slot.
- Snackbar/toast and bottom sheet styles.

## Tooling and Quality
- Flavors: dev, staging, prod with separate API keys and app IDs.
- Environment config via dart-define, never committed secrets.
- Lints: very_good_analysis or flutter_lints with strict rules.
- CI: GitHub Actions running format check, analyze, tests, and a debug build on every PR.
- Widget golden tests for the core components.

## Deliverables
1. Project scaffold with flavors, folder structure, router shell and bottom navigation.
2. Theme file wired into MaterialApp (light and dark token sets).
3. Full component library.
4. A hidden component gallery screen showing every component in every state.
5. CI pipeline green.

## Acceptance Criteria
- App runs on Android and iOS in all three flavors.
- Every component in the gallery matches the reference style and uses only theme tokens.
- Swapping one colour token updates the entire app.
- Analyzer shows zero warnings; component golden tests pass.
