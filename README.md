# Clothsy AI

**AI-powered virtual try-on fashion marketplace built with Flutter.**

Browse curated collections, pick any outfit, upload your photo — and see yourself wearing it in photorealistic quality before you buy.

---

## Project Structure

```
clothsy_ai/
├── lib/
│   ├── app.dart                          # Root MaterialApp + theme setup
│   ├── bootstrap.dart                    # App initialization (flavor-aware)
│   ├── main.dart
│   ├── main_dev.dart                     # Entry point — dev flavor
│   ├── main_staging.dart                 # Entry point — staging flavor
│   ├── main_prod.dart                    # Entry point — production flavor
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart        # App flavors, API base URLs
│   │   ├── errors/
│   │   │   └── app_exception.dart        # Typed error classes
│   │   ├── network/
│   │   │   └── api_client.dart           # HTTP client wrapper
│   │   ├── router/
│   │   │   ├── app_router.dart           # go_router route definitions
│   │   │   └── scaffold_with_nav_bar.dart# Bottom nav shell
│   │   ├── theme/
│   │   │   ├── app_colors.dart           # Color tokens (primary, accent, semantic)
│   │   │   ├── app_radius.dart           # Border radius tokens
│   │   │   ├── app_spacing.dart          # Spacing scale
│   │   │   ├── app_theme.dart            # ThemeData assembly
│   │   │   └── app_typography.dart       # Text styles (display, h1–h3, body, caption, label)
│   │   └── utils/
│   │       └── currency_formatter.dart   # ₹ formatting helper
│   │
│   ├── features/
│   │   ├── address/
│   │   │   ├── data/repositories/address_repository_impl.dart
│   │   │   ├── domain/entities/address.dart
│   │   │   ├── domain/repositories/address_repository.dart
│   │   │   └── presentation/
│   │   │       ├── add_edit_address_screen.dart
│   │   │       ├── address_list_screen.dart
│   │   │       └── providers/address_providers.dart
│   │   │
│   │   ├── auth/
│   │   │   ├── data/repositories/auth_repository_impl.dart
│   │   │   ├── domain/entities/user.dart
│   │   │   ├── domain/repositories/auth_repository.dart
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       ├── otp_verification_screen.dart
│   │   │       └── providers/auth_provider.dart
│   │   │
│   │   ├── cart/
│   │   │   ├── domain/entities/cart_item.dart
│   │   │   └── presentation/
│   │   │       ├── cart_screen.dart
│   │   │       └── providers/cart_provider.dart
│   │   │
│   │   ├── catalog/
│   │   │   ├── data/repositories/catalog_repository_impl.dart
│   │   │   ├── domain/entities/banner.dart
│   │   │   ├── domain/entities/collection.dart
│   │   │   ├── domain/entities/product.dart
│   │   │   ├── domain/repositories/catalog_repository.dart
│   │   │   └── presentation/
│   │   │       ├── catalog_screen.dart
│   │   │       ├── product_detail_screen.dart
│   │   │       └── providers/catalog_providers.dart
│   │   │
│   │   ├── checkout/
│   │   │   └── presentation/
│   │   │       ├── checkout_screen.dart
│   │   │       └── order_success_screen.dart
│   │   │
│   │   ├── gallery/
│   │   │   └── presentation/component_gallery_screen.dart  # Dev: design tokens reference
│   │   │
│   │   ├── home/
│   │   │   └── presentation/home_screen.dart
│   │   │
│   │   ├── notifications/
│   │   │   ├── domain/entities/app_notification.dart
│   │   │   └── presentation/
│   │   │       ├── notifications_screen.dart
│   │   │       └── providers/notifications_provider.dart
│   │   │
│   │   ├── onboarding/
│   │   │   └── presentation/onboarding_screen.dart         # 3-slide editorial intro
│   │   │
│   │   ├── orders/
│   │   │   ├── data/repositories/order_repository_impl.dart
│   │   │   ├── domain/entities/order.dart
│   │   │   ├── domain/repositories/order_repository.dart
│   │   │   └── presentation/
│   │   │       ├── order_detail_screen.dart
│   │   │       ├── orders_list_screen.dart
│   │   │       └── providers/order_providers.dart
│   │   │
│   │   ├── profile/
│   │   │   └── presentation/profile_screen.dart
│   │   │
│   │   ├── search/
│   │   │   └── presentation/search_screen.dart
│   │   │
│   │   ├── splash/
│   │   │   └── presentation/splash_screen.dart
│   │   │
│   │   ├── tryon/
│   │   │   ├── data/repositories/tryon_repository_impl.dart
│   │   │   ├── domain/entities/tryon_photo.dart
│   │   │   ├── domain/entities/tryon_session.dart
│   │   │   ├── domain/repositories/tryon_repository.dart
│   │   │   └── presentation/
│   │   │       ├── providers/tryon_provider.dart
│   │   │       ├── tryon_screen.dart
│   │   │       ├── tryon_history_screen.dart
│   │   │       └── widgets/
│   │   │           ├── before_after_slider.dart
│   │   │           ├── model_photo_picker_sheet.dart
│   │   │           ├── photo_guidance_sheet.dart
│   │   │           └── tryon_shimmer_loading.dart
│   │   │
│   │   └── wishlist/
│   │       └── presentation/
│   │           ├── wishlist_screen.dart
│   │           └── providers/wishlist_provider.dart
│   │
│   └── shared/
│       └── widgets/
│           ├── badges/
│           │   ├── cart_badge_icon.dart
│           │   └── discount_badge.dart
│           ├── buttons/
│           │   ├── clothsy_icon_button.dart
│           │   ├── pressable_scale.dart      # Spring-press animation wrapper
│           │   ├── primary_button.dart
│           │   └── secondary_button.dart
│           ├── cards/
│           │   ├── offer_strip.dart
│           │   ├── product_card.dart
│           │   └── promo_banner.dart
│           ├── feedback/
│           │   ├── clothsy_bottom_sheet.dart
│           │   ├── clothsy_snackbar.dart
│           │   ├── empty_state_view.dart
│           │   ├── error_state_view.dart
│           │   └── skeleton_loader.dart
│           ├── inputs/
│           │   ├── clothsy_otp_field.dart
│           │   ├── clothsy_search_bar.dart
│           │   └── clothsy_text_field.dart
│           ├── navigation/
│           │   └── clothsy_bottom_nav.dart
│           ├── selectors/
│           │   ├── category_chip.dart
│           │   ├── color_swatch_selector.dart
│           │   ├── quantity_stepper.dart
│           │   └── size_selector.dart
│           └── typography/
│               ├── price_row.dart
│               ├── rating_row.dart
│               └── section_header.dart
│
└── test/
    ├── components/
    │   ├── core_components_test.dart
    │   └── responsiveness_test.dart       # 6 screen sizes (320px → 430px)
    ├── features/
    │   ├── auth_and_orders_test.dart
    │   ├── catalog_and_cart_test.dart
    │   └── tryon_test.dart
    └── widget_test.dart
```

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
├── core/           # Theme, router, constants, API client
├── features/       # Auth, home, catalog, tryon, cart, orders, profile…
├── shared/         # Reusable widgets — buttons, cards, inputs, selectors
└── main_*.dart     # Entry points per flavor
test/               # Widget + unit tests (56/56 passing)
```

---

## Tests

```bash
flutter test
```

---

## License

MIT © 2024 Aastha Sudan
