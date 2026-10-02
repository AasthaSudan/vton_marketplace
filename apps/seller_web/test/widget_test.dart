import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clothsy_seller/main.dart';

void main() {
  testWidgets('wide layout shows the sidebar with every section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ClothsySellerApp());

    expect(find.text('Seller Panel'), findsOneWidget);
    for (final section in sellerSections) {
      expect(find.text(section.title), findsWidgets);
    }
    expect(find.text('Coming in Phase 2'), findsOneWidget);
  });

  testWidgets('selecting a section shows its planned areas', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ClothsySellerApp());
    final target = sellerSections[2];
    await tester.tap(find.text(target.title).first);
    await tester.pumpAndSettle();

    for (final item in target.items) {
      expect(find.text(item), findsOneWidget);
    }
  });

  testWidgets('narrow layout uses a drawer without overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ClothsySellerApp());
    expect(tester.takeException(), isNull);
    expect(find.byType(Drawer), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
  });
}
