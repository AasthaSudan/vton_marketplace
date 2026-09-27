import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clothsy_shop/features/catalog/domain/entities/product.dart';
import 'package:clothsy_shop/features/tryon/data/repositories/tryon_repository_impl.dart';
import 'package:clothsy_shop/features/tryon/domain/entities/tryon_photo.dart';
import 'package:clothsy_shop/features/tryon/domain/entities/tryon_session.dart';
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
    price: 8999,
  );

  const sampleProduct = Product(
    id: 'p_silk_shirt',
    handle: 'mulberry-silk-shirt',
    title: 'Mulberry Silk Shirt',
    brand: 'Clothsy Atelier',
    category: 'Tops',
    description: 'Pure Mulberry silk tailored blouse.',
    price: 8999,
    images: [
      'https://images.unsplash.com/photo-1598554747436-c9293d6a588f',
      'https://images.unsplash.com/photo-1598554747436-c9293d6a588f',
    ],
    availableSizes: ['XS', 'S', 'M'],
    variants: [sampleVariant],
  );

  group('Phase 4 - TryOnRepositoryImpl', () {
    late TryOnRepositoryImpl repo;

    setUp(() {
      repo = TryOnRepositoryImpl();
    });

    test('getPresetPhotos returns curated editorial models', () async {
      final presets = await repo.getPresetPhotos();
      expect(presets.length, greaterThanOrEqualTo(4));
      expect(presets.first.isPreset, isTrue);
      expect(presets.first.imageUrl, isNotEmpty);
    });

    test('runTryOn runs full styling pipeline and returns TryOnResult', () async {
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
    });

    test('runTryOn caches result by (photo + product + variant) for instant repeat access', () async {
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
      expect(steps.first.title, contains('Cache'));
    });

    test('saveUserPhoto and deleteUserPhoto manage custom photos', () async {
      final newPhoto = await repo.saveUserPhoto(
        'https://images.unsplash.com/photo-custom',
        'Home Mirror',
      );
      expect(newPhoto.label, equals('Home Mirror'));

      final users = await repo.getUserPhotos();
      expect(users.any((p) => p.id == newPhoto.id), isTrue);

      await repo.deleteUserPhoto(newPhoto.id);
      final usersAfter = await repo.getUserPhotos();
      expect(usersAfter.any((p) => p.id == newPhoto.id), isFalse);
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

    test('TryOnNotifier generateTryOn completes and updates triedOnProductIdsProvider', () async {
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

      // Rate result
      notifier.rateResult(5, 'Stunning drape');
      final ratedState = container.read(tryOnNotifierProvider);
      expect(ratedState.currentResult?.rating, equals(5));
      expect(ratedState.currentResult?.feedbackNote, equals('Stunning drape'));
    });
  });

  group('Phase 4 - BeforeAfterSlider Widget', () {
    testWidgets('BeforeAfterSlider renders before/after labels and slider handle', (tester) async {
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
    });
  });
}
