import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clothsy_core/core/theme/app_theme.dart';
import 'package:clothsy_core/shared/widgets/badges/discount_badge.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/secondary_button.dart';
import 'package:clothsy_core/shared/widgets/selectors/category_chip.dart';
import 'package:clothsy_core/shared/widgets/selectors/quantity_stepper.dart';
import 'package:clothsy_core/shared/widgets/selectors/size_selector.dart';
import 'package:clothsy_core/shared/widgets/typography/price_row.dart';
import 'package:clothsy_core/shared/widgets/typography/rating_row.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('PrimaryButton', () {
    testWidgets('renders button text and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _wrap(
          PrimaryButton(text: 'Add to Bag', onPressed: () => tapped = true),
        ),
      );

      expect(find.text('Add to Bag'), findsOneWidget);
      await tester.tap(find.text('Add to Bag'));
      expect(tapped, isTrue);
    });

    testWidgets('shows loading spinner when isLoading is true', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrimaryButton(text: 'Add to Bag', isLoading: true)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Add to Bag'), findsNothing);
    });
  });

  group('SecondaryButton', () {
    testWidgets('renders secondary outlined button and handles tap', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        _wrap(
          SecondaryButton(text: 'Size Guide', onPressed: () => tapped = true),
        ),
      );

      expect(find.text('Size Guide'), findsOneWidget);
      await tester.tap(find.text('Size Guide'));
      expect(tapped, isTrue);
    });
  });

  group('DiscountBadge', () {
    testWidgets('displays uppercase discount text', (tester) async {
      await tester.pumpWidget(_wrap(const DiscountBadge(text: '30% off')));

      expect(find.text('30% OFF'), findsOneWidget);
    });
  });

  group('PriceRow', () {
    testWidgets('renders current price and strikethrough price', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const PriceRow(price: 299900, originalPrice: 499900)),
      );

      expect(find.text('₹2,999'), findsOneWidget);
      expect(find.text('₹4,999'), findsOneWidget);
      expect(find.text('40% OFF'), findsOneWidget);
    });
  });

  group('RatingRow', () {
    testWidgets('renders rating score and reviews count', (tester) async {
      await tester.pumpWidget(
        _wrap(const RatingRow(rating: 4.8, reviewCount: 142)),
      );

      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('(142)'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });
  });

  group('QuantityStepper', () {
    testWidgets('increments and decrements value on tap', (tester) async {
      int value = 2;

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return QuantityStepper(
                value: value,
                onChanged: (newVal) => setState(() => value = newVal),
              );
            },
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(value, 3);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(value, 2);
    });
  });

  group('CategoryChip', () {
    testWidgets('renders label and triggers tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _wrap(
          CategoryChip(
            label: 'Dresses',
            icon: Icons.checkroom_rounded,
            isSelected: false,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Dresses'), findsOneWidget);
      await tester.tap(find.text('Dresses'));
      expect(tapped, isTrue);
    });
  });

  group('SizeSelector', () {
    testWidgets('selects size chip on tap', (tester) async {
      String selected = 'S';

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return SizeSelector(
                sizes: const ['XS', 'S', 'M', 'L'],
                selectedSize: selected,
                onSizeSelected: (newSize) => setState(() => selected = newSize),
              );
            },
          ),
        ),
      );

      expect(find.text('M'), findsOneWidget);
      await tester.tap(find.text('M'));
      await tester.pump();
      expect(selected, 'M');
    });
  });
}
