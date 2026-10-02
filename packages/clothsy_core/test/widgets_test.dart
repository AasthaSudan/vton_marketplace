import 'package:clothsy_core/core/theme/app_theme.dart';
import 'package:clothsy_core/shared/widgets/cards/product_card.dart';
import 'package:clothsy_core/shared/widgets/inputs/clothsy_otp_field.dart';
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

  group('ClothsyOtpField', () {
    String boxes(WidgetTester tester) => tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.controller!.text)
        .join(',');

    testWidgets('a pasted or autofilled code fills every box', (tester) async {
      final completed = <String>[];
      await tester.pumpWidget(
        _wrap(ClothsyOtpField(onCompleted: completed.add)),
      );

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();

      expect(boxes(tester), '1,2,3,4,5,6');
      expect(completed, ['123456']);
    });

    testWidgets('typing digit by digit moves along and completes once', (
      tester,
    ) async {
      final completed = <String>[];
      await tester.pumpWidget(
        _wrap(ClothsyOtpField(onCompleted: completed.add)),
      );

      final fields = find.byType(TextField);
      for (var i = 0; i < 6; i++) {
        await tester.enterText(fields.at(i), '${i + 1}');
        await tester.pump();
      }

      expect(boxes(tester), '1,2,3,4,5,6');
      expect(completed, ['123456']);
    });

    testWidgets('only digits are kept and extra digits are dropped', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(_wrap(ClothsyOtpField(onChanged: changes.add)));

      await tester.enterText(find.byType(TextField).at(4), '9a87');
      await tester.pump();

      expect(boxes(tester), ',,,,9,8');
      expect(changes.last, '98');
    });
  });
}
