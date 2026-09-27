import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clothsy_shop/app.dart';
import 'package:clothsy_shop/core/constants/app_constants.dart';

void main() {
  testWidgets('ClothsyShopApp smoke test renders navigation and home', (
    WidgetTester tester,
  ) async {
    AppConstants.currentFlavor = AppFlavor.dev;
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});

    await tester.pumpWidget(const ProviderScope(child: ClothsyShopApp()));

    // Pump past the initial splash screen timer (1400ms) to land on Home
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify brand wordmark is rendered in AppBar
    expect(find.text('Clothsy'), findsOneWidget);

    // Verify Bottom Navigation items exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Try-On'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
