# Clothsy AI

**AI-powered virtual try-on fashion marketplace built with Flutter.**

Browse curated collections, pick any outfit, upload your photo — and see yourself wearing it in photorealistic quality before you buy.

---

## Features

- **AI Virtual Try-On** — Upload a photo and see yourself in any outfit instantly
- **Product Catalog** — Browse by category with filters and search
- **Product Detail** — Size, color, quantity, ratings, and reviews
- **Cart & Checkout** — Full shopping bag and order flow
- **Order History** — Track all past orders
- **Wishlist** — Save favourites across sessions
- **Auth** — Phone OTP + Google Sign-In
- **Onboarding** — 3-slide animated editorial intro

---

## Stack

| | |
|---|---|
| Framework | Flutter (Dart) |
| State | Riverpod |
| Navigation | go_router |
| AI Backend | FabricVTON API |
| Fonts | Google Fonts (Playfair Display, Inter) |

---

## Getting Started

```bash
git clone https://github.com/AasthaSudan/vton_marketplace.git
cd vton_marketplace
flutter pub get
flutter run
```

### Flavors

```bash
flutter run -t lib/main_dev.dart       # Development
flutter run -t lib/main_staging.dart   # Staging
flutter run -t lib/main_prod.dart      # Production
```

---

## Project Structure

```
lib/
├── core/
│   ├── constants/      # App flavors, API base URLs
│   ├── errors/         # Typed error classes
│   ├── network/        # HTTP client
│   ├── router/         # go_router routes + bottom nav shell
│   ├── theme/          # Colors, typography, radius, spacing tokens
│   └── utils/          # Currency formatter
│
├── features/
│   ├── address/        # Address management (list, add, edit)
│   ├── auth/           # Phone OTP + Google Sign-In
│   ├── cart/           # Shopping bag + cart provider
│   ├── catalog/        # Product grid, filters, product detail
│   ├── checkout/       # Checkout flow + order success
│   ├── gallery/        # Dev-only: design tokens reference
│   ├── home/           # Home feed, banners, categories
│   ├── notifications/  # In-app notifications
│   ├── onboarding/     # 3-slide editorial intro
│   ├── orders/         # Order list + detail + tracking
│   ├── profile/        # Account settings
│   ├── search/         # Search screen
│   ├── splash/         # Splash screen
│   ├── tryon/          # AI virtual try-on studio + history
│   └── wishlist/       # Saved favourites
│
└── shared/
    └── widgets/
        ├── badges/     # CartBadgeIcon, DiscountBadge
        ├── buttons/    # PrimaryButton, SecondaryButton, IconButton, PressableScale
        ├── cards/      # ProductCard, PromoBanner, OfferStrip
        ├── feedback/   # Snackbar, BottomSheet, EmptyState, ErrorState, Skeletons
        ├── inputs/     # TextField, SearchBar, OtpField
        ├── navigation/ # ClothsyBottomNav
        ├── selectors/  # CategoryChip, SizeSelector, ColorSwatch, QuantityStepper
        └── typography/ # PriceRow, RatingRow, SectionHeader

test/
├── components/         # Responsiveness tests (6 screen sizes: 320px → 430px)
└── features/           # Auth, catalog, cart, try-on unit tests
```

---

## Tests

```bash
flutter test
```

---

## License

MIT © 2024 Aastha Sudan
