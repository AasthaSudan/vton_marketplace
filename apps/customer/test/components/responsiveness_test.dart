import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clothsy_core/core/constants/app_constants.dart';
import 'package:clothsy_shop/features/brands/presentation/brand_directory_screen.dart';
import 'package:clothsy_shop/features/brands/presentation/brand_storefront_screen.dart';
import 'package:clothsy_shop/features/cart/presentation/cart_screen.dart';
import 'package:clothsy_shop/features/cart/presentation/providers/cart_provider.dart';
import 'package:clothsy_shop/features/catalog/data/repositories/mock_catalog_repository.dart';
import 'package:clothsy_shop/features/catalog/presentation/catalog_screen.dart';
import 'package:clothsy_shop/features/catalog/presentation/product_detail_screen.dart';
import 'package:clothsy_shop/features/search/presentation/search_screen.dart';
import 'package:clothsy_shop/features/settings/presentation/settings_screen.dart';
import 'package:clothsy_shop/features/home/presentation/home_screen.dart';
import 'package:clothsy_shop/features/address/presentation/providers/address_providers.dart';
import 'package:clothsy_shop/features/checkout/presentation/checkout_screen.dart';
import 'package:clothsy_shop/features/checkout/presentation/order_success_screen.dart';
import 'package:clothsy_shop/features/onboarding/presentation/onboarding_screen.dart';
import 'package:clothsy_shop/features/onboarding/presentation/style_onboarding_screen.dart';
import 'package:clothsy_shop/features/tryon/presentation/tryon_screen.dart';

void main() {
  const mobileScreenSizes = [
    Size(320, 568), // iPhone SE 1st gen (compact)
    Size(360, 640), // Standard compact Android
    Size(375, 667), // iPhone SE 2nd/3rd gen
    Size(390, 844), // iPhone 13/14
    Size(412, 915), // Pixel 7/8
    Size(430, 932), // iPhone 14/15 Pro Max
  ];

  setUp(() {
    AppConstants.currentFlavor = AppFlavor.dev;
  });

  Widget wrapWithScope(Widget child, Size size) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 44, bottom: 34),
          ),
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );
  }

  group('Universal Mobile Screen Size Responsiveness Tests', () {
    for (final size in mobileScreenSizes) {
      testWidgets(
        'OnboardingScreen renders cleanly on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            wrapWithScope(const OnboardingScreen(), size),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(tester.takeException(), isNull);
          // Kicker of first slide
          expect(find.text('DISCOVER'), findsOneWidget);
          // First slide has "Next" button; "Get Started" appears only on final slide
          expect(find.text('Next'), findsOneWidget);
          // Skip link always visible
          expect(find.text('Skip'), findsOneWidget);
        },
      );

      testWidgets(
        'StyleOnboardingScreen walks every step on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            wrapWithScope(const StyleOnboardingScreen(), size),
          );
          await tester.pump();
          expect(find.text('What should we call you?'), findsOneWidget);

          for (final title in [
            'What do you shop for?',
            'Pick looks you like',
            'Brands you love',
            'Your usual budget',
          ]) {
            await tester.tap(find.text('Continue'));
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
            expect(find.text(title), findsOneWidget);
          }
          expect(find.text('Show my feed'), findsOneWidget);
        },
      );

      testWidgets(
        'Explore (CatalogScreen) renders on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(wrapWithScope(const CatalogScreen(), size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          expect(find.text('Explore'), findsOneWidget);
          expect(find.textContaining('pieces'), findsOneWidget);
        },
      );

      testWidgets(
        'SearchScreen suggestions render on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(wrapWithScope(const SearchScreen(), size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(tester.takeException(), isNull);
          expect(find.text('Trending searches'), findsOneWidget);
        },
      );

      testWidgets(
        'SettingsScreen renders on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(wrapWithScope(const SettingsScreen(), size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(tester.takeException(), isNull);
          expect(find.text('Delete my try-on photos'), findsOneWidget);
        },
      );

      testWidgets(
        'HomeScreen renders cleanly on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(wrapWithScope(const HomeScreen(), size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(tester.takeException(), isNull);
          expect(find.text('Clothsy'), findsOneWidget);
          expect(find.text('Shop by brand'), findsOneWidget);

          // Best Picks sits below the brand strip on small phones: scroll to it.
          await tester.scrollUntilVisible(
            find.text('Best Picks'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          expect(find.text('Best Picks'), findsOneWidget);
        },
      );

      testWidgets(
        'BrandDirectoryScreen lists every brand on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            wrapWithScope(const BrandDirectoryScreen(), size),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          expect(find.text('Brands'), findsOneWidget);
          expect(find.text('Noor Atelier'), findsOneWidget);
          expect(find.text('Studio Rao'), findsOneWidget);
        },
      );

      testWidgets(
        'BrandStorefrontScreen renders on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            wrapWithScope(
              const BrandStorefrontScreen(sellerId: 'sel_noor'),
              size,
            ),
          );
          await tester.pump();
          // First the seller loads, then the storefront starts loading its
          // products: let both mock delays finish.
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          expect(find.text('About'), findsOneWidget);
          expect(
            find.text('Hand-finished occasion & workwear'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'CartScreen groups a two-brand bag by seller on ${size.width}x${size.height}',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final catalog = MockCatalogRepository();
          // The mock repository uses real timers, so resolve it outside the
          // widget tester's fake clock.
          final blazer = (await tester.runAsync(
            () => catalog.getProductById('p_lavender_blazer'),
          ))!;
          final shirt = (await tester.runAsync(
            () => catalog.getProductById('p_minimal_overshirt'),
          ))!;
          container
              .read(cartProvider.notifier)
              .addToCart(blazer, blazer.variants.first);
          container
              .read(cartProvider.notifier)
              .addToCart(shirt, shirt.variants.first);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    padding: const EdgeInsets.only(top: 44, bottom: 34),
                  ),
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: const CartScreen(),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull);
          expect(find.text('Noor Atelier'), findsOneWidget);
          expect(find.text('Studio Rao'), findsOneWidget);

          await tester.scrollUntilVisible(
            find.text('Delivery (2 shipments)'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Checkout shows one shipment per brand on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final catalog = MockCatalogRepository();
          final blazer = (await tester.runAsync(
            () => catalog.getProductById('p_lavender_blazer'),
          ))!;
          final shirt = (await tester.runAsync(
            () => catalog.getProductById('p_minimal_overshirt'),
          ))!;
          container.read(cartProvider.notifier)
            ..addToCart(blazer, blazer.variants.first)
            ..addToCart(shirt, shirt.variants.first);
          // Load the saved addresses so one is selected.
          container.read(addressesProvider);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(size: size),
                  child: const CheckoutScreen(),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          expect(find.text('2. Delivery'), findsOneWidget);
          expect(find.text('Noor Atelier'), findsOneWidget);
          expect(find.textContaining('Arrives by'), findsWidgets);
        },
      );

      testWidgets(
        'OrderSuccessScreen lists each shipment on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            wrapWithScope(const OrderSuccessScreen(orderId: 'ord_103'), size),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          expect(find.text('Noor Atelier'), findsOneWidget);
          expect(find.text('Studio Rao'), findsOneWidget);
        },
      );

      testWidgets(
        'ProductDetailScreen renders cleanly on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            wrapWithScope(
              const ProductDetailScreen(productId: 'p_lavender_blazer'),
              size,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          // Try-On eligible product: "Try it on" sits beside "Add to bag".
          expect(find.text('Try it on'), findsOneWidget);
          expect(find.text('Add to bag'), findsOneWidget);
        },
      );

      testWidgets(
        'TryonScreen renders cleanly on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(wrapWithScope(const TryonScreen(), size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          expect(find.text('Clothsy AI Try-On'), findsOneWidget);
        },
      );
    }
  });
}
