import 'dart:typed_data';

import 'package:clothsy_seller/app.dart';
import 'package:clothsy_seller/core/files.dart';
import 'package:clothsy_seller/core/providers.dart';
import 'package:clothsy_seller/core/router.dart';
import 'package:clothsy_seller/data/models.dart';
import 'package:clothsy_seller/printing/invoice_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_seller_repository.dart';

final printed = <String>[];

Future<void> pumpPanel(
  WidgetTester tester,
  FakeSellerRepository repo, {
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  printed.clear();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sellerRepositoryProvider.overrideWithValue(repo),
        pickFileProvider.overrideWithValue(
          (_) async => PickedFile('shirt.jpg', Uint8List(4)),
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
      await tester.tap(find.text('Inventory'));
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
