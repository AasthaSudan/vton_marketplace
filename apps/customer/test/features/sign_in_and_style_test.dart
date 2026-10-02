import 'package:clothsy_core/features/profile/domain/entities/style_preferences.dart';
import 'package:clothsy_shop/core/router/app_router.dart';
import 'package:clothsy_shop/features/auth/presentation/login_screen.dart';
import 'package:clothsy_shop/features/auth/presentation/providers/auth_provider.dart';
import 'package:clothsy_shop/features/profile/data/mock_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Sign-in guard', () {
    test('protects checkout, orders, addresses and try-on history only', () {
      for (final path in [
        '/checkout',
        '/orders',
        '/orders/ord_1',
        '/order-success/ord_1',
        '/addresses',
        '/tryon/history',
        '/style-preferences',
      ]) {
        expect(needsSignIn(path), isTrue, reason: path);
      }
      for (final path in [
        '/',
        '/explore',
        '/tryon',
        '/bag',
        '/profile',
        '/product/p1',
        '/brand/sel_noor',
        '/search',
      ]) {
        expect(needsSignIn(path), isFalse, reason: path);
      }
    });

    Future<GoRouter> pumpRouter(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      // Let the stored session (none) be restored.
      await tester.pump();
      await tester.pump();
      return router;
    }

    String location(GoRouter router) =>
        router.routerDelegate.currentConfiguration.uri.toString();

    testWidgets('a signed-out shopper is sent to sign in, then back', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = await pumpRouter(tester, container);

      router.go('/orders');
      await tester.pump();
      await tester.pump();

      expect(location(router), '/login?redirect=%2Forders');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('browsing stays open to guests', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = await pumpRouter(tester, container);

      router.go('/search');
      await tester.pump();
      await tester.pump();

      expect(location(router), '/search');
    });

    testWidgets('the mock flavor lets a guest check out', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = await pumpRouter(tester, container);

      container.read(authProvider.notifier).continueAsGuest();
      router.go('/addresses');
      await tester.pump();
      await tester.pump();

      expect(location(router), '/addresses');
      // Let the address list's mock delay finish.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Style preferences', () {
    test('survive a JSON round trip', () {
      final prefs = StylePreferences(
        categories: const ['women', 'dresses'],
        looks: const ['minimal'],
        brandIds: const ['sel_noor'],
        budget: BudgetRange.upTo2500,
        completedAt: DateTime.utc(2026, 10, 2, 9, 30),
      );
      final back = StylePreferences.fromJson(prefs.toJson());
      expect(back.categories, prefs.categories);
      expect(back.looks, prefs.looks);
      expect(back.brandIds, prefs.brandIds);
      expect(back.budget, BudgetRange.upTo2500);
      expect(back.completedAt, prefs.completedAt);
    });

    test('unknown or missing values fall back safely', () {
      final prefs = StylePreferences.fromJson(const {
        'categories': ['women', 3],
        'budget': 'millionaire',
      });
      expect(prefs.categories, ['women']);
      expect(prefs.budget, isNull);
      expect(prefs.completedAt, isNull);
    });

    test(
      'skipping everything still records that onboarding was shown',
      () async {
        final repo = MockProfileRepository();
        expect(await repo.getStylePreferences(), isNull);

        await repo.saveStylePreferences(
          StylePreferences(completedAt: DateTime(2026, 10, 2)),
        );
        final saved = await repo.getStylePreferences();
        expect(saved, isNotNull);
        expect(saved!.isEmpty, isTrue);
      },
    );
  });
}
