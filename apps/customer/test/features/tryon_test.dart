import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/features/tryon/domain/repositories/tryon_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_shop/features/tryon/data/repositories/mock_tryon_repository.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_photo.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_session.dart';
import 'package:clothsy_shop/features/tryon/presentation/providers/tryon_provider.dart';
import 'package:clothsy_shop/features/tryon/presentation/widgets/before_after_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const sampleVariant = ProductVariant(
    id: 'var_test_1',
    title: 'Ivory - S',
    size: 'S',
    colorName: 'Ivory',
    colorHex: '#F7F5F9',
    price: 899900,
  );

  const sampleProduct = Product(
    id: 'p_silk_shirt',
    handle: 'mulberry-silk-shirt',
    title: 'Mulberry Silk Shirt',
    sellerId: 'sel_noor',
    brand: 'Noor Atelier',
    category: 'Tops',
    description: 'Pure Mulberry silk tailored blouse.',
    price: 899900,
    images: [
      'https://images.unsplash.com/photo-1598554747436-c9293d6a588f',
      'https://images.unsplash.com/photo-1598554747436-c9293d6a588f',
    ],
    availableSizes: ['XS', 'S', 'M'],
    variants: [sampleVariant],
  );

  group('Phase 4 - MockTryOnRepository', () {
    late MockTryOnRepository repo;

    setUp(() {
      repo = MockTryOnRepository();
    });

    test('getPresetPhotos returns curated editorial models', () async {
      final presets = await repo.getPresetPhotos();
      expect(presets.length, greaterThanOrEqualTo(4));
      expect(presets.first.isPreset, isTrue);
      expect(presets.first.imageUrl, isNotEmpty);
    });

    test(
      'runTryOn runs full styling pipeline and returns TryOnResult',
      () async {
        final presets = await repo.getPresetPhotos();
        final photo = presets.first;

        final progressSteps = <ProcessingStep>[];
        final result = await repo.runTryOn(
          photo: photo,
          product: sampleProduct,
          variant: sampleVariant,
          onProgress: (step) => progressSteps.add(step),
        );

        expect(result.id, startsWith('try_'));
        expect(result.product.id, equals(sampleProduct.id));
        expect(result.variant.id, equals(sampleVariant.id));
        expect(result.resultImageUrl, isNotEmpty);
        expect(progressSteps.isNotEmpty, isTrue);
        expect(progressSteps.last.progress, equals(1.0));
      },
    );

    test(
      'runTryOn caches result by (photo + product + variant) for instant repeat access',
      () async {
        final presets = await repo.getPresetPhotos();
        final photo = presets.first;

        // First run takes several pipeline steps
        final first = await repo.runTryOn(
          photo: photo,
          product: sampleProduct,
          variant: sampleVariant,
        );

        final steps = <ProcessingStep>[];
        final second = await repo.runTryOn(
          photo: photo,
          product: sampleProduct,
          variant: sampleVariant,
          onProgress: (step) => steps.add(step),
        );

        // Instant cache hit
        expect(second.cacheKey, equals(first.cacheKey));
        expect(steps.length, equals(1));
        expect(steps.first.title, contains('saved preview'));
      },
    );

    test('own photos need consent, expire and can be deleted', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      await expectLater(
        repo.uploadUserPhoto(bytes, contentType: 'image/jpeg'),
        throwsA(
          isA<TryOnException>().having((e) => e.code, 'code', 'NO_CONSENT'),
        ),
      );

      await repo.setUserConsent(true);
      final photo = await repo.uploadUserPhoto(
        bytes,
        contentType: 'image/jpeg',
        label: 'Home mirror',
      );
      expect(photo.label, 'Home mirror');
      expect(photo.isPreset, isFalse);
      expect(photo.bytes, bytes);
      expect(
        photo.expiresAt!.difference(photo.createdAt),
        MockTryOnRepository.retention,
      );
      expect((await repo.getUserPhotos()).single.id, photo.id);

      await repo.deleteUserPhoto(photo.id);
      expect(await repo.getUserPhotos(), isEmpty);
    });

    test('withdrawing consent deletes photos and their previews', () async {
      await repo.setUserConsent(true);
      final photo = await repo.uploadUserPhoto(
        Uint8List.fromList([9]),
        contentType: 'image/png',
      );
      await repo.runTryOn(
        photo: photo,
        product: sampleProduct,
        variant: sampleVariant,
      );
      expect(
        (await repo.getHistory()).any((h) => h.photo.id == photo.id),
        isTrue,
      );

      await repo.setUserConsent(false);
      expect(await repo.getUserPhotos(), isEmpty);
      expect((await repo.getHistory()).any((h) => !h.photo.isPreset), isFalse);
    });

    test('each new preview uses a credit; cached ones do not', () async {
      final preset = (await repo.getPresetPhotos()).first;
      final before = await repo.getRemainingCredits();
      await repo.runTryOn(
        photo: preset,
        product: sampleProduct,
        variant: sampleVariant,
      );
      await repo.runTryOn(
        photo: preset,
        product: sampleProduct,
        variant: sampleVariant,
      );
      expect(await repo.getRemainingCredits(), before - 1);

      // Regenerating asks for a fresh preview and uses another credit.
      await repo.runTryOn(
        photo: preset,
        product: sampleProduct,
        variant: sampleVariant,
        forceRefresh: true,
      );
      expect(await repo.getRemainingCredits(), before - 2);
    });

    test('runs out of credits gracefully', () async {
      SharedPreferences.setMockInitialValues({'clothsy_tryon_credits_v1': 0});
      final preset = (await repo.getPresetPhotos()).first;
      await expectLater(
        repo.runTryOn(
          photo: preset,
          product: sampleProduct,
          variant: sampleVariant,
        ),
        throwsA(
          isA<TryOnException>().having((e) => e.code, 'code', 'NO_CREDITS'),
        ),
      );
    });

    test('unsupported pieces are explained, not attempted', () async {
      final preset = (await repo.getPresetPhotos()).first;
      const tote = Product(
        id: 'p_tote',
        handle: 'tote',
        title: 'Leather Tote',
        sellerId: 'sel_mehr',
        brand: 'Mehr Essentials',
        description: '',
        price: 499900,
        images: [],
        availableSizes: ['One size'],
        variants: [sampleVariant],
        category: 'Bags',
        isTryonEligible: false,
      );
      await expectLater(
        repo.runTryOn(photo: preset, product: tote, variant: sampleVariant),
        throwsA(
          isA<TryOnException>().having((e) => e.code, 'code', 'NOT_ELIGIBLE'),
        ),
      );
    });

    test('history management stores and deletes try-on results', () async {
      final initialHistory = await repo.getHistory();
      final initialCount = initialHistory.length;

      final presets = await repo.getPresetPhotos();
      final res = await repo.runTryOn(
        photo: presets[1],
        product: sampleProduct,
        variant: sampleVariant,
      );

      final updatedHistory = await repo.getHistory();
      expect(updatedHistory.length, equals(initialCount + 1));
      expect(updatedHistory.first.id, equals(res.id));

      await repo.deleteHistoryItem(res.id);
      final afterDelete = await repo.getHistory();
      expect(afterDelete.any((h) => h.id == res.id), isFalse);
    });

    test('user consent persistence', () async {
      expect(await repo.hasUserConsented(), isFalse);
      await repo.setUserConsent(true);
      expect(await repo.hasUserConsented(), isTrue);
    });
  });

  group('Phase 4 - TryOnNotifier Riverpod Provider', () {
    test('TryOnNotifier builds and allows photo & garment selection', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Wait for session initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final notifier = container.read(tryOnNotifierProvider.notifier);

      final photo = TryOnPhoto(
        id: 'photo_test',
        label: 'Test Model',
        imageUrl: 'https://images.unsplash.com/photo-test',
        createdAt: DateTime.now(),
      );

      notifier.selectPhoto(photo);
      notifier.selectGarment(sampleProduct, sampleVariant);

      final state = container.read(tryOnNotifierProvider);
      expect(state.selectedPhoto?.id, equals('photo_test'));
      expect(state.selectedProduct?.id, equals(sampleProduct.id));
      expect(state.selectedVariant?.id, equals(sampleVariant.id));
      expect(state.canGenerate, isTrue);
    });

    test(
      'TryOnNotifier generateTryOn completes and updates triedOnProductIdsProvider',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 100));
        final notifier = container.read(tryOnNotifierProvider.notifier);

        final presets = await container.read(tryOnPresetsProvider.future);
        notifier.selectPhoto(presets.first);
        notifier.selectGarment(sampleProduct, sampleVariant);

        final result = await notifier.generateTryOn();
        expect(result, isNotNull);

        final state = container.read(tryOnNotifierProvider);
        expect(state.status, equals(TryOnJobStatus.completed));
        expect(state.currentResult, isNotNull);

        // Check tried-on badge provider
        final triedIds = container.read(triedOnProductIdsProvider);
        expect(triedIds.contains(sampleProduct.id), isTrue);

        // Save the look
        notifier.saveLook();
        final saved = container.read(tryOnNotifierProvider);
        expect(saved.currentResult?.rating, equals(5));
      },
    );

    test('cancelling throws the late result away', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final notifier = container.read(tryOnNotifierProvider.notifier);
      notifier.selectPhoto(
        (await container.read(tryOnPresetsProvider.future)).first,
      );
      notifier.selectGarment(sampleProduct, sampleVariant);

      final pending = notifier.generateTryOn();
      notifier.cancel();
      expect(await pending, isNull);

      final state = container.read(tryOnNotifierProvider);
      expect(state.status, TryOnJobStatus.idle);
      expect(state.currentResult, isNull);
      expect(
        container.read(triedOnProductIdsProvider).contains(sampleProduct.id),
        isFalse,
      );
    });

    test('errors reach the screen as friendly messages', () async {
      SharedPreferences.setMockInitialValues({'clothsy_tryon_credits_v1': 0});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final notifier = container.read(tryOnNotifierProvider.notifier);
      notifier.selectPhoto(
        (await container.read(tryOnPresetsProvider.future)).first,
      );
      notifier.selectGarment(sampleProduct, sampleVariant);

      expect(await notifier.generateTryOn(), isNull);
      final state = container.read(tryOnNotifierProvider);
      expect(state.status, TryOnJobStatus.failed);
      expect(state.errorMessage, ClothsyCopy.tryOnNoCredits);
    });
  });

  group('Phase 4 - BeforeAfterSlider Widget', () {
    testWidgets(
      'BeforeAfterSlider renders before/after labels and slider handle',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 500,
                child: BeforeAfterSlider(
                  beforeImageUrl: 'https://images.unsplash.com/photo-before',
                  afterImageUrl: 'https://images.unsplash.com/photo-after',
                  beforeLabel: 'Original',
                  afterLabel: 'Clothsy AI Drape',
                ),
              ),
            ),
          ),
        );

        expect(find.text('Original'), findsOneWidget);
        expect(find.text('Clothsy AI Drape'), findsOneWidget);
        expect(find.byIcon(Icons.compare_arrows_rounded), findsOneWidget);
      },
    );
  });
}
