import 'package:flutter_test/flutter_test.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clothsy_shop/features/auth/presentation/providers/auth_provider.dart';
import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_shop/features/address/data/repositories/mock_address_repository.dart';
import 'package:clothsy_shop/features/address/presentation/providers/address_providers.dart';
import 'package:clothsy_shop/features/orders/data/repositories/mock_order_repository.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_shop/features/notifications/presentation/providers/notifications_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3 - Auth Flow', () {
    test(
      'AuthNotifier initial state starts as unauthenticated when no stored session',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // wait for async auth check
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final authState = container.read(authProvider);
        expect(authState.isAuthenticated, isFalse);
        expect(authState.user, isNull);
      },
    );

    test('AuthNotifier sends OTP and verifies login successfully', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      final sent = await notifier.sendPhoneOtp('+91 98765 00000');
      expect(sent, isTrue);

      final success = await notifier.verifyOtp('+91 98765 00000', '1234');
      expect(success, isTrue);

      final loggedInUser = container.read(authProvider).user;
      expect(loggedInUser, isNotNull);
      expect(loggedInUser?.phone, contains('98765 00000'));
    });

    test('AuthNotifier updateProfile modifies user profile details', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await notifier.verifyOtp('+91 98765 00000', '1234');
      await notifier.updateProfile(
        name: 'Lady Aastha',
        email: 'lady.aastha@clothsy.studio',
      );

      final user = container.read(authProvider).user;
      expect(user?.name, equals('Lady Aastha'));
      expect(user?.email, equals('lady.aastha@clothsy.studio'));
    });

    test('AuthNotifier signOut clears user state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await notifier.verifyOtp('+91 98765 00000', '1234');
      expect(container.read(authProvider).isAuthenticated, isTrue);

      await notifier.signOut();
      final authState = container.read(authProvider);
      expect(authState.isAuthenticated, isFalse);
      expect(authState.user, isNull);
    });
  });

  group('Phase 3 - Address Repository & PIN Code Serviceability', () {
    final repo = MockAddressRepository();

    test('PIN code lookup resolves city and state correctly', () async {
      final delhi = await repo.lookupPinCode('110001');
      expect(delhi, isNotNull);
      expect(delhi?['city'], equals('New Delhi'));
      expect(delhi?['state'], equals('Delhi'));

      final mumbai = await repo.lookupPinCode('400001');
      expect(mumbai, isNotNull);
      expect(mumbai?['city'], equals('Mumbai'));
      expect(mumbai?['state'], equals('Maharashtra'));

      final blr = await repo.lookupPinCode('560001');
      expect(blr, isNotNull);
      expect(blr?['city'], equals('Bengaluru'));
      expect(blr?['state'], equals('Karnataka'));
    });

    test('PIN code serviceability returns boolean status', () async {
      final isServiceable = await repo.checkPinServiceability('110001');
      expect(isServiceable, isTrue);
    });

    test(
      'Addresses notifier loads addresses and allows adding new address',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Trigger load and wait for repo response
        container.read(addressesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        const newAddr = Address(
          id: 'addr_kolkata_1',
          name: 'Anita Roy',
          phone: '+91 99999 88888',
          street: 'Park Street 24',
          city: 'Kolkata',
          state: 'West Bengal',
          pinCode: '700016',
          isDefault: false,
        );

        await container.read(addressesProvider.notifier).addAddress(newAddr);
        final updated = container.read(addressesProvider);
        expect(updated.any((a) => a.pinCode == '700016'), isTrue);
      },
    );
  });

  group('Phase 3 - Orders and Checkout', () {
    test('OrderRepository creates and cancels order', () async {
      final repo = MockOrderRepository();

      const sampleVariant = ProductVariant(
        id: 'var_test',
        title: 'Midnight Plum - M',
        size: 'M',
        colorName: 'Midnight Plum',
        colorHex: '#2B1E3F',
        price: 499900,
      );

      const sampleProduct = Product(
        id: 'p_test',
        handle: 'silk-slip-dress',
        title: 'Silk Slip Dress',
        sellerId: 'sel_rao',
        brand: 'Studio Rao',
        category: 'Dresses',
        description: 'Luxury pure mulberry silk slip dress.',
        originalPrice: 799900,
        price: 499900,
        images: [
          'https://images.unsplash.com/photo-1595777457583-95e059d581b8',
        ],
        availableSizes: ['XS', 'S', 'M', 'L'],
        variants: [sampleVariant],
      );

      final newOrder = await repo.createOrder(
        items: const [
          CartLineItem(
            id: 'cart_item_1',
            product: sampleProduct,
            variant: sampleVariant,
            quantity: 1,
          ),
        ],
        address: const Address(
          id: 'addr_1',
          name: 'Aastha Sudan',
          phone: '+91 98765 43210',
          street: 'Defence Colony',
          city: 'New Delhi',
          state: 'Delhi',
          pinCode: '110024',
        ),
        method: PaymentMethod.cashOnDelivery,
        paymentLabel: 'Cash on delivery',
        discount: 50000,
      );

      expect(newOrder.orderNumber, startsWith('CLY-'));
      expect(newOrder.status, equals(OrderStatus.placed));
      // Totals are computed from the items, not passed in by the caller.
      expect(newOrder.total, equals(449900));

      final cancelled = await repo.cancelOrder(
        newOrder.id,
        'Ordered by mistake',
      );
      expect(cancelled.status, equals(OrderStatus.cancelled));
    });
  });

  group('Phase 3 - Notifications', () {
    test('NotificationsNotifier loads list and updates read status', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(notificationsProvider);
      expect(initial.isNotEmpty, isTrue);

      final unreadCountInitial = container.read(
        unreadNotificationsCountProvider,
      );
      expect(unreadCountInitial, greaterThan(0));

      final unreadItem = initial.firstWhere((n) => !n.isRead);
      container.read(notificationsProvider.notifier).markAsRead(unreadItem.id);

      final updated = container.read(notificationsProvider);
      final itemAfter = updated.firstWhere((n) => n.id == unreadItem.id);
      expect(itemAfter.isRead, isTrue);

      container.read(notificationsProvider.notifier).markAllAsRead();
      final allReadCount = container.read(unreadNotificationsCountProvider);
      expect(allReadCount, equals(0));
    });
  });
}
