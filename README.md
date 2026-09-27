# Clothsy AI — Virtual Try-On Fashion Marketplace

> A premium Flutter e-commerce app with **AI-powered virtual try-on**, an editorial design system, and a full shopping experience — built for mobile-first.

---

## What is Clothsy?

Clothsy is a fashion marketplace app that lets you **virtually try on clothes before buying** using AI. Browse curated collections, pick a garment, upload your photo, and see yourself wearing it — instantly, in photorealistic quality.

Think of it as your personal stylist + fitting room, in your pocket.

---

## Key Features

| Feature | Description |
|---|---|
| **AI Virtual Try-On** | Upload a photo → see yourself wearing any outfit, powered by FabricVTON |
| **Product Catalog** | Browse by category (Men, Women, Shoes, Bags) with filters & search |
| **Product Detail** | Size selector, color swatches, quantity stepper, ratings, reviews |
| **Cart & Checkout** | Full shopping bag flow with address, payment & order confirmation |
| **Orders & History** | Track past orders and try-on history |
| **Wishlist** | Save favourites across sessions |
| **Auth** | Phone OTP login + Google Sign-In |
| **Profile** | Manage account, addresses, preferences |
| **Onboarding** | 3-slide animated editorial onboarding |
| **Design Tokens** | In-app design system reference (colors, typography, buttons) |

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Dart) |
| **State Management** | Riverpod (code-gen) |
| **Navigation** | go_router |
| **Backend / AI** | FabricVTON API (virtual try-on) |
| **Local Storage** | shared_preferences, Hive |
| **Image Loading** | cached_network_image |
| **Fonts** | Google Fonts (Playfair Display, Inter) |
| **Testing** | flutter_test, mocktail |

---

## Project Structure

```
lib/
├── core/
│   ├── theme/          # AppColors, AppTypography, AppRadius — design tokens
│   ├── router/         # go_router config — all app routes
│   └── constants/      # App flavors (dev / staging / prod), API keys
│
├── features/
│   ├── onboarding/     # 3-slide animated editorial intro
│   ├── auth/           # Phone OTP + Google Sign-In
│   ├── home/           # Home feed, promo banners, category chips
│   ├── catalog/        # Product grid, filters, search
│   ├── product_detail/ # PDP — sizes, colors, try-on, add to cart
│   ├── tryon/          # AI virtual try-on studio
│   ├── cart/           # Shopping bag + checkout
│   ├── orders/         # Order history + tracking
│   ├── wishlist/       # Saved items
│   ├── profile/        # Account settings
│   └── gallery/        # Dev-only: design tokens reference
│
├── shared/
│   └── widgets/        # Reusable UI components
│       ├── buttons/    # PrimaryButton, SecondaryButton, ClothsyIconButton
│       ├── cards/      # ProductCard, PromoBanner, OfferStrip
│       ├── inputs/     # ClothsyTextField, SearchBar, OtpField
│       ├── selectors/  # CategoryChip, SizeSelector, ColorSwatchSelector
│       ├── badges/     # DiscountBadge, CartBadgeIcon
│       ├── feedback/   # Snackbar, BottomSheet, EmptyState, ErrorState, Skeletons
│       └── typography/ # PriceRow, RatingRow, SectionHeader
│
└── main_dev.dart       # Entry point — dev flavor
    main_staging.dart   # Entry point — staging flavor
    main_prod.dart      # Entry point — production flavor
```

---

## Running Locally

### Prerequisites
- Flutter SDK ≥ 3.22
- Dart ≥ 3.4
- An Android emulator / iOS simulator / Chrome (for web)

### Setup

```bash
# 1. Clone
git clone https://github.com/AasthaSudan/vton_marketplace.git
cd vton_marketplace

# 2. Install dependencies
flutter pub get

# 3. Run (dev flavor)
flutter run -d chrome          # Web (Chrome)
flutter run                    # Default connected device
```

### Flavors

```bash
flutter run -t lib/main_dev.dart       # Development
flutter run -t lib/main_staging.dart   # Staging
flutter run -t lib/main_prod.dart      # Production
```

---

## Testing

```bash
# Run all tests
flutter test

# Run only responsiveness tests (all 6 screen sizes)
flutter test test/components/responsiveness_test.dart

# Run AI try-on unit tests
flutter test test/features/tryon_test.dart
```

**Current test coverage:** 56/56 tests passing across:
- Universal responsiveness (320×568 → 430×932)
- Try-on repository & Riverpod notifier
- Widget rendering

---

## Design System

The app uses a custom design system defined in `lib/core/theme/`:

- **Colors** — Plum Noir primary (`#2B1E3F`), Soft Lilac accent, semantic success/error/rating tokens
- **Typography** — Playfair Display for editorial headlines, Inter for body/UI text
- **Radius** — sm(8) / md(16) / lg(24) / pill(100) — consistent card & button rounding
- **Spacing** — 4pt grid system

View the live reference inside the app: **Profile → Design Tokens**

---

## App Flavors / Environments

| Flavor | File | Purpose |
|---|---|---|
| `dev` | `main_dev.dart` | Local development, mock data |
| `staging` | `main_staging.dart` | QA testing with real API |
| `prod` | `main_prod.dart` | Live production build |

---

## Screenshots

> Coming soon — run the app to see the editorial onboarding, product catalog, and virtual try-on studio.

---

## Contributing

1. Fork the repo
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Commit with a clear message: `git commit -m "feat: add size recommendation widget"`
4. Push and open a Pull Request

---

## License

MIT © 2024 Aastha Sudan / Clothsy AI
