// The Seller Panel's real repository against the local Docker backend:
// every query and action the screens use, plus a shopper's order that the
// seller fulfils. Skipped unless asked for:
//
//   scripts/backend.sh reset
//   cd apps/seller_web && flutter test test/live \
//     --dart-define-from-file=../customer/config/dev.json \
//     --dart-define=LIVE_BACKEND=true
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:clothsy_seller/data/models.dart';
import 'package:clothsy_seller/data/seller_repository.dart';
import 'package:clothsy_seller/data/supabase_seller_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const live = bool.fromEnvironment('LIVE_BACKEND');
const url = String.fromEnvironment('SUPABASE_URL');
const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

SupabaseClient client() => SupabaseClient(
  url,
  anonKey,
  // The app's client keeps PKCE state in browser storage; a test client has
  // none, so it uses the implicit flow.
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
);

// A 1×1 PNG.
final png = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, //
  0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84,
  120, 156, 99, 248, 207, 192, 240, 31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0,
  0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

Future<Object?> failure(Future<Object?> Function() f) async {
  try {
    await f();
    return null;
  } on SellerFailure catch (e) {
    return e.code;
  }
}

void main() {
  final stamp = DateTime.now().millisecondsSinceEpoch;

  group('A new brand', skip: !live, () {
    final repo = SupabaseSellerRepository(client());

    test('signs up, registers and is told exactly what is missing', () async {
      await repo.signUp(
        email: 'live-$stamp@brand.test',
        password: 'brand-pass-123',
        fullName: 'Live Founder',
      );
      expect(repo.isSignedIn, isTrue);
      await repo.registerSeller('Live Brand $stamp');
      final seller = (await repo.mySellers()).single;
      expect(seller.applicationStatus, 'draft');
      expect(seller.missing, containsAll(['pan', 'bank_account']));
      expect(
        await failure(() => repo.submitApplication(seller.sellerId)),
        'APPLICATION_INCOMPLETE',
      );

      final app = await repo.application(seller.sellerId);
      expect(app.ownerName, 'Live Founder');
      await repo.saveApplication(
        seller.sellerId,
        const SellerApplication(
          ownerName: 'Live Founder',
          contactEmail: 'live@brand.test',
          contactPhone: '+919999900031',
          businessType: 'individual',
          legalName: 'Live Brand',
          pan: 'ABCPL1234F',
          pickupLine1: '1 Road',
          pickupCity: 'New Delhi',
          pickupState: 'Delhi',
          pickupPinCode: '110001',
        ),
      );
      final bank = await repo.setBankAccount(
        seller.sellerId,
        accountHolder: 'Live Brand',
        accountNumber: '123456789012',
        ifsc: 'HDFC0000123',
      );
      expect(bank.last4, '9012');
      for (final kind in ['pan_card', 'cancelled_cheque']) {
        await repo.uploadDocument(
          seller.sellerId,
          kind: kind,
          fileName: '$kind.png',
          bytes: png,
          contentType: 'image/png',
        );
      }
      final docs = await repo.documents(seller.sellerId);
      expect(
        docs.map((d) => d.kind),
        containsAll(['pan_card', 'cancelled_cheque']),
      );
      expect((await repo.mySellers()).single.missing, isEmpty);
      await repo.submitApplication(seller.sellerId);
      expect((await repo.mySellers()).single.applicationStatus, 'submitted');
      expect(
        (await repo.applicationHistory(seller.sellerId)).map((e) => e.toStatus),
        ['draft', 'submitted'],
      );
      await repo.signOut();
    });
  });

  group('An approved brand (seller@clothsy.test)', skip: !live, () {
    final repo = SupabaseSellerRepository(client());
    final shopper = client();
    late SellerContext store;
    late String productId;
    late String variantId;

    setUpAll(() async {
      await repo.signIn(
        email: 'seller@clothsy.test',
        password: 'clothsy-local',
      );
      store = (await repo.mySellers()).single;
    });

    test('opens on its approved store and business details', () async {
      expect(store.handle, 'noor-atelier');
      expect(store.isApproved, isTrue);
      expect((await repo.application(store.sellerId)).gstin, '07ABCPK1234F1Z5');
      expect((await repo.bankAccount(store.sellerId))!.status, 'verified');
      final dash = await repo.dashboard(store.sellerId);
      expect(dash.products['live'], greaterThan(0));
    });

    test('edits its storefront and collections', () async {
      final before = await repo.storefront(store.sellerId);
      final logo = await repo.uploadImage(
        store.sellerId,
        fileName: 'logo.png',
        bytes: png,
        contentType: 'image/png',
      );
      await repo.saveStorefront(store.sellerId, before.copyWith(logoUrl: logo));
      expect((await repo.storefront(store.sellerId)).logoUrl, logo);

      final products = await repo.products(store.sellerId);
      await repo.saveCollection(
        store.sellerId,
        title: 'Live Edit $stamp',
        description: '',
        productIds: [products.first.id],
        isVisible: true,
      );
      final c = (await repo.collections(
        store.sellerId,
      )).firstWhere((c) => c.title == 'Live Edit $stamp');
      expect(c.productIds, [products.first.id]);
      await repo.deleteCollection(c.id);
    });

    test('lists a product: draft, size, photo, review', () async {
      final image = await repo.uploadImage(
        store.sellerId,
        fileName: 'shirt.png',
        bytes: png,
        contentType: 'image/png',
      );
      productId = await repo.createProduct(
        store.sellerId,
        ProductDraft(
          title: 'Live Shirt $stamp',
          description: 'Breathable linen shirt with a relaxed fit.',
          category: 'Tops',
          categoryHandles: const ['women', 'tops'],
          images: [image],
          tryOnRequested: true,
          hsnCode: '6206',
        ),
      );
      await repo.addVariant(
        productId,
        VariantDraft(sku: 'LIVE-$stamp', size: 'M', price: 159900, stock: 3),
      );
      expect(
        await failure(
          () => repo.addVariant(
            productId,
            VariantDraft(sku: 'LIVE-$stamp', size: 'L', price: 159900),
          ),
        ),
        'DUPLICATE_SKU',
      );
      var product = await repo.product(productId);
      variantId = product.variants.single.id;
      await repo.updateVariant(
        variantId,
        VariantDraft(
          sku: 'LIVE-$stamp',
          size: 'M',
          price: 149900,
          compareAtPrice: 199900,
          lowStockThreshold: 2,
        ),
      );
      await repo.submitProduct(productId);
      product = await repo.product(productId);
      expect(product.status, 'pending_review');
      expect(product.variants.single.price, 149900);
      expect(product.variants.single.stock, 3);
      expect(
        await failure(() => repo.submitProduct(productId)),
        'NOT_SUBMITTABLE',
      );
      expect(await failure(() => repo.setListed(productId, false)), 'NOT_LIVE');
    });

    test('adjusts and bulk-imports stock, with history', () async {
      expect(await repo.adjustStock(variantId, 2, note: 'Live restock'), 5);
      expect(
        await failure(() => repo.adjustStock(variantId, -50)),
        'INSUFFICIENT_STOCK',
      );
      final r = await repo.bulkSetStock(store.sellerId, [
        (sku: 'LIVE-$stamp', stock: 9),
      ]);
      expect(r.updated, 1);
      final history = await repo.stockHistory(store.sellerId);
      expect(history.first.sku, 'LIVE-$stamp');
      expect(history.first.reason, 'bulk_import');
      expect(history[1].note, 'Live restock');
      expect(
        await failure(
          () => repo.bulkSetStock(store.sellerId, [
            (sku: 'NOPE-$stamp', stock: 1),
          ]),
        ),
        'INVALID_IMPORT',
      );
    });

    test('fulfils a shopper\'s order end to end', () async {
      // A shopper buys a Noor Atelier blazer (₹7,999, free shipping).
      await shopper.auth.signInWithOtp(phone: '+919999900002');
      await shopper.auth.verifyOTP(
        type: OtpType.sms,
        phone: '+919999900002',
        token: '123456',
      );
      final address = await shopper
          .from('addresses')
          .insert({
            'name': 'Live Shopper',
            'phone': '+919999900002',
            'line1': '9 Janpath',
            'city': 'New Delhi',
            'state': 'Delhi',
            'pin_code': '110001',
          })
          .select('id')
          .single();
      final blazer = await shopper
          .from('product_variants')
          .select('id, price')
          .eq('sku', 'v_blazer_lavender')
          .single();
      final res = await shopper.functions.invoke(
        'create-order',
        body: {
          'items': [
            {'variant_id': blazer['id'], 'quantity': 1},
          ],
          'address_id': address['id'],
          'payment_method': 'cod',
          'payment_label': 'COD',
          'idempotency_key':
              '00000000-0000-4000-8000-${stamp.toString().padLeft(12, '0').substring(0, 12)}',
          'expected_total': blazer['price'],
        },
      );
      final orderId = (res.data as Map)['order_id'] as String;

      var order = (await repo.orders(
        store.sellerId,
      )).firstWhere((o) => o.orderId == orderId);
      expect(order.status, 'placed');
      expect(order.items.single.title, contains('Blazer'));
      expect(order.dispatchBy, isNotNull);
      await repo.acceptOrder(order.id);
      final invoiceNumber = await repo.packOrder(order.id);
      expect(invoiceNumber, startsWith('NOOR/'));
      final invoice = await repo.invoice(order.id);
      expect(invoice['intra_state'], isTrue);
      expect((invoice['totals'] as Map)['total'], blazer['price']);
      await repo.shipOrder(
        order.id,
        carrier: 'Delhivery',
        trackingNumber: 'LIVE$stamp',
      );
      order = (await repo.orders(
        store.sellerId,
      )).firstWhere((o) => o.id == order.id);
      expect(order.status, 'shipped');
      expect(order.shipment!.trackingNumber, 'LIVE$stamp');
      expect(
        await failure(() => repo.cancelOrder(order.id, 'Too late')),
        'NOT_CANCELLABLE',
      );
      await repo.markDelivered(order.id);

      final settlement = (await repo.settlements(
        store.sellerId,
      )).firstWhere((s) => s.reference == order.reference);
      expect(settlement.gross, blazer['price']);
      expect(settlement.status, 'pending');
      await repo.payouts(store.sellerId);
      await repo.adjustments(store.sellerId);
    });

    test('sees its insights', () async {
      expect(await repo.salesDaily(store.sellerId, days: 7), hasLength(7));
      expect(
        (await repo.topProducts(store.sellerId)).map((p) => p.title),
        isNotEmpty,
      );
      await repo.tryOnInsights(store.sellerId);
      final dash = await repo.dashboard(store.sellerId);
      expect(dash.sales30dOrders, greaterThan(0));
    });
  });
}
