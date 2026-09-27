import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clothsy_shop/core/constants/app_constants.dart';
import 'package:clothsy_shop/features/catalog/presentation/product_detail_screen.dart';
import 'package:clothsy_shop/features/home/presentation/home_screen.dart';
import 'package:clothsy_shop/features/onboarding/presentation/onboarding_screen.dart';
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
        'HomeScreen renders cleanly on ${size.width}x${size.height} with zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(wrapWithScope(const HomeScreen(), size));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(tester.takeException(), isNull);
          expect(find.text('Clothsy'), findsOneWidget);
          expect(find.text('Best Picks'), findsOneWidget);
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
          expect(find.text('Add to Cart'), findsOneWidget);
          expect(find.text('Buy Now'), findsOneWidget);
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
          expect(find.text('Virtual Try-On'), findsOneWidget);
        },
      );
    }
  });
}
