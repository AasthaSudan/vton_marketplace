import 'dart:convert';
import 'package:clothsy_core/core/constants/app_constants.dart';
import 'package:clothsy_shop/features/cart/data/cart_storage.dart';
import 'package:clothsy_shop/features/cart/presentation/providers/cart_provider.dart';
import 'package:clothsy_shop/features/catalog/data/repositories/mock_catalog_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle() => Future<void>.delayed(const Duration(seconds: 1));

  test('the bag and its coupon survive a restart', () async {
    final catalog = MockCatalogRepository();
    final blazer = (await catalog.getProductById('p_lavender_blazer'))!;

    final first = ProviderContainer();
    first.read(cartProvider.notifier).addToCart(blazer, blazer.variants.first);
    expect(
      await first.read(cartProvider.notifier).applyCoupon('CLOTHSY10'),
      isNull,
    );
    await settle();
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(cartProvider);
    await settle();

    final bag = second.read(cartProvider);
    expect(bag.items.single.product.id, 'p_lavender_blazer');
    expect(bag.couponCode, 'CLOTHSY10');
    expect(bag.discountAmount, 79990);
  });

  test('pieces that no longer exist are dropped on restore', () async {
    SharedPreferences.setMockInitialValues({
      'clothsy_bag_v1_mock': jsonEncode({
        'lines': [
          {'product_id': 'gone', 'variant_id': 'v', 'quantity': 1},
          {
            'product_id': 'p_minimal_overshirt',
            'variant_id': 'v_overshirt_sand',
            'quantity': 2,
          },
        ],
        'coupon': null,
      }),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(cartProvider);
    await settle();

    final bag = container.read(cartProvider);
    expect(bag.items.single.variant.id, 'v_overshirt_sand');
    expect(bag.items.single.quantity, 2);
  });

  test('corrupt storage is ignored', () async {
    SharedPreferences.setMockInitialValues({'clothsy_bag_v1_mock': '{oops'});
    final (lines, coupon) = await const CartStorage('mock').load();
    expect(lines, isEmpty);
    expect(coupon, isNull);
  });

  test('quantities are capped by the per-order limit', () async {
    final catalog = MockCatalogRepository();
    final tee = (await catalog.getProductById('p_minimal_overshirt'))!;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(cartProvider.notifier);

    notifier.addToCart(tee, tee.variants.first, quantity: 50);
    expect(
      container.read(cartProvider).items.single.quantity,
      AppConstants.maxQuantityPerLine,
    );
    await settle();
  });
}
