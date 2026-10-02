import 'package:clothsy_core/core/theme/app_theme.dart';
import 'package:clothsy_core/shared/widgets/cards/product_card.dart';
import 'package:clothsy_core/shared/widgets/navigation/clothsy_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {Size size = const Size(320, 568)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('ProductCard sizing', () {
    test('image is portrait 3:4 and height follows width', () {
      expect(ProductCard.imageAspectRatio, 3 / 4);
      expect(ProductCard.heightForWidth(150), 200 + ProductCard.infoHeight);
    });

    for (final width in [320.0, 375.0, 430.0]) {
      testWidgets('grid of long prices fits at ${width.toInt()}px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const ProductCardGridDelegate(),
              itemCount: 4,
              itemBuilder: (context, i) => const ProductCard(
                id: 'p',
                brand: 'An Independent Label With A Long Name',
                title: 'Hand-tailored Double-faced Cashmere Wrap Coat',
                price: 1299900,
                originalPrice: 1899900,
                imageUrl: '',
              ),
            ),
            size: Size(width, 900),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ClothsyBottomNav', () {
    testWidgets('shows blueprint tabs with Clothsy AI at the centre', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(ClothsyBottomNav(currentIndex: 0, onTap: (_) {})),
      );
      final labels = ClothsyBottomNav.items.map((i) => i.label).toList();
      expect(labels, ['Home', 'Explore', 'Clothsy AI', 'Bag', 'Profile']);
      expect(
        ClothsyBottomNav.items[ClothsyBottomNav.clothsyAiIndex].isSpecial,
        isTrue,
      );
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('bag badge shows count and caps at 9+', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ClothsyBottomNav(
            currentIndex: 0,
            onTap: (_) {},
            badgeCounts: const {ClothsyBottomNav.bagIndex: 3},
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          ClothsyBottomNav(
            currentIndex: 0,
            onTap: (_) {},
            badgeCounts: const {ClothsyBottomNav.bagIndex: 12},
          ),
        ),
      );
      expect(find.text('9+'), findsOneWidget);
    });

    testWidgets('tapping a tab reports its index', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        _wrap(ClothsyBottomNav(currentIndex: 0, onTap: (i) => tapped = i)),
      );
      await tester.tap(find.text('Clothsy AI'));
      expect(tapped, ClothsyBottomNav.clothsyAiIndex);
    });
  });
}
