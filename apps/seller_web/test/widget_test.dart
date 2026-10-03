import 'dart:typed_data';

import 'package:clothsy_seller/app.dart';
import 'package:clothsy_seller/core/files.dart';
import 'package:clothsy_seller/core/providers.dart';
import 'package:clothsy_seller/core/router.dart';
import 'package:clothsy_seller/features/inventory/inventory_screen.dart';
import 'package:clothsy_seller/features/money/money_screen.dart';
import 'package:clothsy_seller/data/models.dart';
import 'package:clothsy_seller/printing/invoice_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_seller_repository.dart';

final printed = <String>[];
final saved = <String, String>{};

Future<void> pumpPanel(
  WidgetTester tester,
  FakeSellerRepository repo, {
  Size size = const Size(1280, 900),
  PickedFile? picked,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  printed.clear();
  saved.clear();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sellerRepositoryProvider.overrideWithValue(repo),
        saveTextProvider.overrideWithValue(
          (String name, String content, {String mimeType = 'text/csv'}) =>
              saved[name] = content,
        ),
        pickFileProvider.overrideWithValue(
          (_) async => picked ?? PickedFile('shirt.jpg', Uint8List(4)),
        ),
        printPdfProvider.overrideWithValue((
          Uint8List bytes,
          String name,
        ) async {
          printed.add('$name ${String.fromCharCodes(bytes.take(4))}');
        }),
      ],
      child: const ClothsySellerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view, then taps it.
Future<void> tapShown(WidgetTester tester, Finder finder) async {
  // Let any confirmation snackbar finish so it does not cover the button.
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
}

Finder field(String label) => find.widgetWithText(TextFormField, label).first;

void main() {
  group('Signing in and joining', () {
    testWidgets('signed out, the panel asks you to sign in', (tester) async {
      final repo = FakeSellerRepository();
      await pumpPanel(tester, repo);
      expect(find.text('Welcome back'), findsOneWidget);

      await tester.enterText(field('Email'), 'founder@kiet.test');
      await tester.enterText(field('Password'), 'wrong');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(
        find.text('That email and password do not match.'),
        findsOneWidget,
      );
    });

    testWidgets('a new brand registers and sees exactly what is missing', (
      tester,
    ) async {
      final repo = FakeSellerRepository(signedIn: true);
      await pumpPanel(tester, repo);
      expect(find.text('Sell on Clothsy'), findsOneWidget);

      await tester.enterText(field('Brand name'), 'Kiet Threads');
      await tester.tap(find.text('Start my application'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('register Kiet Threads'));
      expect(find.text('Complete your application'), findsOneWidget);
      expect(find.text('Still needed before you can submit'), findsOneWidget);
      for (final label in ["Owner's name", 'PAN', 'Bank account for payouts']) {
        expect(find.widgetWithText(Chip, label), findsOneWidget);
      }
      // Nothing can be submitted yet.
      await tester.tap(find.text('Submit application'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.calls, isNot(contains('submit application')));
    });

    testWidgets('a store in review shows where it stands', (tester) async {
      final repo = FakeSellerRepository(
        signedIn: true,
        sellers: [
          FakeSellerRepository.store(
            status: 'pending',
            applicationStatus: 'submitted',
          ),
        ],
      );
      await pumpPanel(tester, repo);
      expect(
        find.text('Clothsy is reviewing your application'),
        findsOneWidget,
      );
      expect(find.text('Save details'), findsNothing);
    });

    testWidgets('a request for more information shows the reviewer note', (
      tester,
    ) async {
      final repo = FakeSellerRepository(
        signedIn: true,
        sellers: [
          FakeSellerRepository.store(
            status: 'pending',
            applicationStatus: 'needs_info',
            reviewNote: 'The cheque photo is blurred',
          ),
        ],
      );
      await pumpPanel(tester, repo);
      expect(find.text('A little more information is needed'), findsOneWidget);
      expect(find.text('The cheque photo is blurred'), findsOneWidget);
      expect(find.text('Save details'), findsOneWidget);
    });
  });

  group('An approved store', () {
    FakeSellerRepository approved({List<SellerOrder>? orders}) =>
        FakeSellerRepository(
          signedIn: true,
          sellers: [FakeSellerRepository.store()],
          orders: orders,
          dashboard: const SellerDashboard(
            newOrders: 1,
            late: 0,
            sales30dGmv: 189900,
            sales30dOrders: 1,
            performanceScore: 100,
          ),
        );

    testWidgets('opens on the dashboard with what needs doing', (tester) async {
      await pumpPanel(tester, approved());
      expect(find.text('Hello, Kiet Threads'), findsOneWidget);
      expect(find.text('New — accept'), findsOneWidget);
      expect(find.text('₹1,899'), findsOneWidget);
      expect(find.text('100 / 100'), findsOneWidget);
    });

    testWidgets('an order goes from new to delivered', (tester) async {
      final repo = approved(orders: [FakeSellerRepository.order()]);
      await pumpPanel(tester, repo);
      await tester.tap(find.text('New — accept'));
      await tester.pumpAndSettle();
      expect(find.text('CLY-10000001-A'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('accept so1'));

      await tester.tap(find.text('To pack (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Pack'));
      await tester.pumpAndSettle();
      expect(find.text('Print the invoice and label?'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Print'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      expect(printed, ['Clothsy-KIET-2627-00001 %PDF']);

      await tester.tap(find.text('To ship (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Ship'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      expect(find.text('6 to 30 letters or digits'), findsOneWidget);
      await tester.enterText(field('Tracking (AWB) number'), 'DLV123456');
      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('ship so1 Delhivery DLV123456'));

      await tester.tap(find.text('In transit (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark delivered'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delivered'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('deliver so1'));
      expect(find.text('Delivered (1)'), findsOneWidget);
    });

    testWidgets('cancelling asks for the reason the shopper sees', (
      tester,
    ) async {
      final repo = approved(orders: [FakeSellerRepository.order()]);
      await pumpPanel(tester, repo);
      await tester.tap(find.text('New — accept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLY-10000001-A'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel order'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tell the shopper why you are cancelling.'),
        findsOneWidget,
      );
      expect(repo.calls.where((c) => c.startsWith('cancel')), isEmpty);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel order'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Sold out in store');
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('cancel so1 Sold out in store'));
      expect(find.textContaining('Sold out in store'), findsOneWidget);
    });

    testWidgets('late orders are flagged', (tester) async {
      final repo = approved(
        orders: [
          FakeSellerRepository.order(
            dispatchBy: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ],
      );
      await pumpPanel(tester, repo);
      await tester.tap(find.text('New — accept'));
      await tester.pumpAndSettle();
      expect(find.text('Late'), findsOneWidget);
    });

    testWidgets('fits a phone: dashboard, drawer and orders at 375 px', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        approved(orders: [FakeSellerRepository.order()]),
        size: const Size(375, 812),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orders').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('CLY-10000001-A'), findsOneWidget);
    });

    testWidgets('sections still to come say so', (tester) async {
      await pumpPanel(tester, approved());
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('Coming in Phase 2'), findsOneWidget);
    });
  });

  group('Products', () {
    FakeSellerRepository store() => FakeSellerRepository(
      signedIn: true,
      sellers: [FakeSellerRepository.store()],
    );

    testWidgets('a new listing: draft, size, photo, then review', (
      tester,
    ) async {
      final repo = store();
      await pumpPanel(tester, repo);
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('No products yet'), findsOneWidget);

      await tester.tap(find.text('Add product').first);
      await tester.pumpAndSettle();
      await tapShown(tester, find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(find.text('At least 3 characters'), findsOneWidget);

      await tester.enterText(field('Title'), 'Linen Shirt');
      await tapShown(tester, find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('create Linen Shirt'));
      expect(find.textContaining('Draft — add photos'), findsOneWidget);

      // Submitting too early lists what is missing.
      await tapShown(tester, find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(find.text('Needed before review'), findsOneWidget);
      expect(find.text('At least one photo'), findsOneWidget);

      await tapShown(tester, find.text('Add size'));
      await tester.pumpAndSettle();
      await tester.enterText(field('SKU'), 'KLS-M');
      await tester.enterText(field('Size'), 'M');
      await tester.enterText(field('Selling price (₹)'), '1899');
      await tester.enterText(field('MRP (₹, optional)'), '1500');
      await tester.tap(find.widgetWithText(FilledButton, 'Add size'));
      await tester.pumpAndSettle();
      expect(find.text('Above the price'), findsOneWidget);
      await tester.enterText(field('MRP (₹, optional)'), '2499');
      await tester.tap(find.widgetWithText(FilledButton, 'Add size'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('add variant KLS-M 189900'));
      expect(find.text('KLS-M'), findsOneWidget);

      await tapShown(tester, find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('upload image shirt.jpg'));
      await tester.enterText(
        field('Description'),
        'Breathable linen with a relaxed fit and shell buttons.',
      );
      await tapShown(tester, find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('submit p1'));
      expect(
        find.textContaining('Clothsy is reviewing this listing'),
        findsOneWidget,
      );
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('a live listing is unpublished and put back on sale', (
      tester,
    ) async {
      final repo = store();
      repo.productList.add(
        FakeSellerRepository.sampleProduct(
          status: 'live',
          approvedAt: DateTime(2026, 10, 1),
        ),
      );
      await pumpPanel(tester, repo);
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Linen Shirt'));
      await tester.pumpAndSettle();
      await tapShown(tester, find.text('Unpublish'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('listed p1 false'));
      await tapShown(tester, find.text('Put back on sale'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('listed p1 true'));
      expect(find.textContaining('On sale.'), findsOneWidget);
    });

    testWidgets("changes needed: the list shows Clothsy's reason", (
      tester,
    ) async {
      final repo = store();
      repo.productList.addAll([
        FakeSellerRepository.sampleProduct(
          status: 'rejected',
          rejectionReason: 'Photos show a watermark',
        ),
        FakeSellerRepository.sampleProduct(
          id: 'p2',
          title: 'Silk Scarf',
          status: 'live',
        ),
      ]);
      await pumpPanel(tester, repo);
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('Clothsy: Photos show a watermark'), findsOneWidget);
      await tester.tap(find.text('Live (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Silk Scarf'), findsOneWidget);
      expect(find.text('Linen Shirt'), findsNothing);
    });
  });

  group('Inventory', () {
    FakeSellerRepository stocked() {
      final repo = FakeSellerRepository(
        signedIn: true,
        sellers: [FakeSellerRepository.store()],
      );
      repo.productList.add(
        FakeSellerRepository.sampleProduct(
          status: 'live',
          variants: const [
            SellerVariant(
              id: 'v1',
              productId: 'p1',
              sku: 'KLS-M',
              title: 'Ivory / M',
              size: 'M',
              price: 189900,
              stock: 2,
              isLowStock: true,
            ),
            SellerVariant(
              id: 'v2',
              productId: 'p1',
              sku: 'KLS-L',
              title: 'Ivory / L',
              size: 'L',
              price: 189900,
              stock: 10,
            ),
          ],
        ),
      );
      return repo;
    }

    testWidgets('low stock is flagged and topped up with a note', (
      tester,
    ) async {
      final repo = stocked();
      await pumpPanel(tester, repo);
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('KLS-L'), findsOneWidget);

      await tester.tap(find.text('Low stock (1)'));
      await tester.pumpAndSettle();
      expect(find.text('KLS-L'), findsNothing);

      await tester.tap(find.text('Adjust KLS-M'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Units'), '5');
      await tester.enterText(field('Note (optional)'), 'New delivery');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('adjust v1 5 New delivery'));
      expect(find.text('Low stock (0)'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('Restock — New delivery'), findsOneWidget);
    });

    testWidgets('removing more than is available is refused', (tester) async {
      final repo = stocked();
      await pumpPanel(tester, repo);
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adjust KLS-M'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.enterText(field('Units'), '3');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Only 2 available'), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('adjust')), isEmpty);
    });

    testWidgets('a bulk import with an unknown SKU changes nothing', (
      tester,
    ) async {
      final repo = stocked();
      await pumpPanel(
        tester,
        repo,
        picked: PickedFile(
          'stock.csv',
          Uint8List.fromList('sku,stock\nKLS-M,8\nNOPE,1\n'.codeUnits),
        ),
      );
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import stock CSV'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();
      expect(
        find.text('These SKUs are not in your catalogue: NOPE'),
        findsOneWidget,
      );
      expect(repo.calls.where((c) => c.startsWith('bulk')), isEmpty);
    });

    testWidgets('a good bulk import sets the units available', (tester) async {
      final repo = stocked();
      await pumpPanel(
        tester,
        repo,
        picked: PickedFile(
          'stock.csv',
          Uint8List.fromList('sku,stock\nKLS-M,8\nKLS-L,10\n'.codeUnits),
        ),
      );
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import stock CSV'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('bulk KLS-M=8 KLS-L=10'));
      expect(find.text('1 updated, 1 unchanged'), findsOneWidget);
    });

    test('stock CSVs: header optional, bad lines reported', () {
      final ok = parseStockCsv('KLS-M,8\r\nKLS-L;0\n\n');
      expect(ok.rows, [(sku: 'KLS-M', stock: 8), (sku: 'KLS-L', stock: 0)]);
      expect(ok.errors, isEmpty);
      final bad = parseStockCsv('sku,stock\nKLS-M,-1\n,4\nKLS-L,ten\n');
      expect(bad.rows, isEmpty);
      expect(bad.errors, hasLength(3));
    });
  });

  group('Store', () {
    FakeSellerRepository store() {
      final repo = FakeSellerRepository(
        signedIn: true,
        sellers: [FakeSellerRepository.store()],
      );
      repo.productList.add(FakeSellerRepository.sampleProduct(status: 'live'));
      return repo;
    }

    testWidgets('the storefront is edited and saved with a new logo', (
      tester,
    ) async {
      final repo = store();
      await pumpPanel(tester, repo);
      await tester.tap(find.text('Store').first);
      await tester.pumpAndSettle();
      expect(find.text('Linen from Ghaziabad'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined).first);
      await tester.pumpAndSettle();
      expect(repo.calls, contains('upload image shirt.jpg'));

      await tester.enterText(field('Tagline'), 'Handwoven linen');
      await tester.enterText(field('Dispatch within (days)'), '0');
      await tapShown(tester, find.text('Save storefront'));
      await tester.pumpAndSettle();
      expect(find.text('1 to 30'), findsOneWidget);

      await tester.enterText(field('Dispatch within (days)'), '3');
      await tapShown(tester, find.text('Save storefront'));
      await tester.pumpAndSettle();
      expect(
        repo.calls,
        contains(
          'save storefront Handwoven linen dispatch=3 '
          'logo=https://example.com/shirt.jpg',
        ),
      );
    });

    testWidgets('a collection groups products for the storefront', (
      tester,
    ) async {
      final repo = store();
      await pumpPanel(tester, repo);
      await tester.tap(find.text('Store').first);
      await tester.pumpAndSettle();
      await tapShown(tester, find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Collection name'), 'Summer Linen');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Linen Shirt'));
      await tester.tap(find.text('Save collection'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('collection Summer Linen [p1] true'));
      expect(find.text('Summer Linen'), findsOneWidget);
      expect(find.text('1 product'), findsOneWidget);

      await tapShown(tester, find.byTooltip('Delete Summer Linen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('delete collection c1'));
    });
  });

  group('Money', () {
    final delivered = DateTime(2026, 9, 20);
    Settlement settlement(String ref, String status, {String? payout}) =>
        Settlement(
          id: ref,
          reference: ref,
          gross: 99900,
          commission: 14985,
          shippingFee: 6000,
          collectionFee: 1998,
          gstOnFees: 4137,
          net: 72780,
          status: status,
          deliveredAt: delivered,
          eligibleAt: delivered.add(const Duration(days: 7)),
          payoutId: payout,
        );

    FakeSellerRepository paidStore() {
      final repo = FakeSellerRepository(
        signedIn: true,
        sellers: [FakeSellerRepository.store()],
      );
      repo.bank = const BankAccount(
        accountHolder: 'Kiet Threads',
        last4: '7766',
        ifsc: 'HDFC0000123',
        status: 'verified',
      );
      repo.settlementList.addAll([
        settlement('CLY-1-A', 'paid', payout: 'po1'),
        settlement('CLY-2-A', 'eligible'),
        settlement('CLY-3-A', 'pending'),
      ]);
      repo.payoutList.add(
        Payout(
          id: 'po1',
          amount: 72780,
          status: 'paid',
          utr: 'UTR0001',
          accountLast4: '7766',
          settlementCount: 1,
          createdAt: DateTime(2026, 9, 28),
        ),
      );
      repo.adjustmentList.add(
        Adjustment(
          amount: -72780,
          reason: 'Returned after payout: CLY-1-A',
          createdAt: DateTime(2026, 10, 1),
        ),
      );
      return repo;
    }

    testWidgets('balances, payouts with UTR and every fee per order', (
      tester,
    ) async {
      await pumpPanel(tester, paidStore());
      await tester.tap(find.text('Money').first);
      await tester.pumpAndSettle();
      expect(find.text('Ready for payout'), findsNWidgets(2));
      expect(find.text('UTR0001'), findsOneWidget);
      expect(
        find.text('Kiet Threads · ••••7766 · HDFC0000123'),
        findsOneWidget,
      );
      expect(find.text('To be deducted'), findsOneWidget);
      expect(find.textContaining('Payable 27 Sep'), findsOneWidget);
      expect(find.text('– ₹149.85'), findsNWidgets(3));
    });

    testWidgets('the statement downloads as CSV', (tester) async {
      await pumpPanel(tester, paidStore());
      await tester.tap(find.text('Money').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download statement'));
      await tester.pump();
      expect(saved.keys.single, startsWith('clothsy-statement-'));
      expect(
        saved.values.single,
        contains('Order,CLY-2-A,2026-09-20,999.00,-149.85'),
      );
    });

    test('statement CSV: orders, then adjustments, quoted when needed', () {
      final csv = buildStatementCsv(
        [settlement('CLY-9-A', 'eligible')],
        [
          Adjustment(
            amount: -500,
            reason: 'Damaged, returned',
            createdAt: DateTime(2026, 10, 2),
          ),
        ],
      ).split('\n');
      expect(csv[0], startsWith('Type,Reference,Delivered,Gross sales'));
      expect(
        csv[1],
        'Order,CLY-9-A,2026-09-20,999.00,-149.85,-60.00,-19.98,-41.37,727.80,'
        'Ready for payout,',
      );
      expect(
        csv[2],
        'Adjustment,"Damaged, returned",2026-10-02,,,,,,-5.00,Next payout,',
      );
    });
  });

  test('the invoice and label print as one PDF', () async {
    final bytes = await buildInvoicePdf(
      FakeSellerRepository.invoiceFor(FakeSellerRepository.order()),
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  group('Where the panel sends you', () {
    String? to(
      String path, {
      bool signedIn = true,
      bool loaded = true,
      bool hasStore = true,
      bool approved = true,
    }) => sellerRedirect(
      signedIn: signedIn,
      seller: loaded
          ? const AsyncData<Object?>(null)
          : const AsyncLoading<Object?>(),
      hasStore: hasStore,
      isApproved: approved,
      path: path,
    );

    test('signed out → sign in', () {
      expect(to('/orders', signedIn: false), '/sign-in');
      expect(to('/sign-in', signedIn: false), isNull);
    });
    test('while the store loads → loading', () {
      expect(to('/orders', loaded: false), '/loading');
    });
    test('no store yet → register', () {
      expect(to('/dashboard', hasStore: false), '/register');
    });
    test('not approved yet → the application only', () {
      expect(to('/orders', approved: false), '/application');
      expect(to('/application', approved: false), isNull);
    });
    test('approved → the panel', () {
      expect(to('/sign-in'), '/dashboard');
      expect(to('/application'), '/dashboard');
      expect(to('/orders/so1'), isNull);
    });
  });
}
