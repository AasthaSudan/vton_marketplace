import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_photo.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_session.dart';
import 'package:clothsy_core/features/tryon/domain/repositories/tryon_repository.dart';

class TryOnRepositoryImpl implements TryOnRepository {
  static const String _keyConsent = 'clothsy_tryon_consent_v1';
  static const String _keyCredits = 'clothsy_tryon_credits_v1';

  final List<TryOnPhoto> _presets = [
    TryOnPhoto(
      id: 'preset_model_1',
      label: 'Elena (Studio Neutral)',
      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      isPreset: true,
      createdAt: DateTime(2026, 1, 1),
    ),
    TryOnPhoto(
      id: 'preset_model_2',
      label: 'Sora (Editorial Minimal)',
      imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9',
      isPreset: true,
      createdAt: DateTime(2026, 1, 2),
    ),
    TryOnPhoto(
      id: 'preset_model_3',
      label: 'Zara (Daylight Chic)',
      imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
      isPreset: true,
      createdAt: DateTime(2026, 1, 3),
    ),
    TryOnPhoto(
      id: 'preset_model_4',
      label: 'Marcus (Tailored Fit)',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
      isPreset: true,
      createdAt: DateTime(2026, 1, 4),
    ),
  ];

  final List<TryOnPhoto> _userPhotos = [];
  final Map<String, TryOnResult> _cache = {};
  final List<TryOnResult> _history = [];

  TryOnRepositoryImpl() {
    // Seed initial demo history
    _seedInitialHistory();
  }

  void _seedInitialHistory() {
    const demoVariant = ProductVariant(
      id: 'var_sample_1',
      title: 'Midnight Plum - S',
      size: 'S',
      colorName: 'Midnight Plum',
      colorHex: '#2B1E3F',
      price: 1899900,
    );

    const demoProduct = Product(
      id: 'p1',
      handle: 'cashmere-wrap-coat',
      title: 'Cashmere Wrap Coat',
      brand: 'Clothsy Atelier',
      category: 'Outerwear',
      description: 'Hand-tailored double-faced Mongolian cashmere wrap coat.',
      price: 1899900,
      images: [
        'https://images.unsplash.com/photo-1539533018447-63fcce2678e3',
        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea',
      ],
      availableSizes: ['XS', 'S', 'M', 'L'],
      variants: [demoVariant],
    );

    final preset = _presets.first;
    final initialResult = TryOnResult(
      id: 'try_init_1',
      photo: preset,
      product: demoProduct,
      variant: demoVariant,
      resultImageUrl:
          'https://images.unsplash.com/photo-1539533018447-63fcce2678e3',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      rating: 5,
    );

    _history.add(initialResult);
    _cache[initialResult.cacheKey] = initialResult;
  }

  @override
  Future<List<TryOnPhoto>> getPresetPhotos() async {
    return List.unmodifiable(_presets);
  }

  @override
  Future<List<TryOnPhoto>> getUserPhotos() async {
    return List.unmodifiable(_userPhotos);
  }

  @override
  Future<TryOnPhoto> saveUserPhoto(String imageUrl, String label) async {
    final photo = TryOnPhoto(
      id: 'user_photo_${DateTime.now().millisecondsSinceEpoch}',
      label: label.isEmpty ? 'My Studio Photo' : label,
      imageUrl: imageUrl,
      isPreset: false,
      createdAt: DateTime.now(),
    );
    _userPhotos.insert(0, photo);
    return photo;
  }

  @override
  Future<void> deleteUserPhoto(String id) async {
    _userPhotos.removeWhere((p) => p.id == id);
    _cache.removeWhere((key, _) => key.startsWith('${id}_'));
  }

  @override
  Future<TryOnResult> runTryOn({
    required TryOnPhoto photo,
    required Product product,
    required ProductVariant variant,
    void Function(ProcessingStep step)? onProgress,
  }) async {
    final cacheKey = '${photo.id}_${product.id}_${variant.id}';

    // Instant return if cached
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      onProgress?.call(
        const ProcessingStep(
          title: 'Loaded from Atelier Cache',
          description: 'Instant preview ready',
          progress: 1.0,
        ),
      );
      return cached;
    }

    // Step 1: Geometry & Pose Analysis
    onProgress?.call(
      const ProcessingStep(
        title: 'Analyzing Silhouette',
        description: 'Mapping body landmarks & shoulder alignment...',
        progress: 0.25,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 650));

    // Step 2: Garment Contours
    onProgress?.call(
      const ProcessingStep(
        title: 'Segmenting Garment',
        description: 'Extracting collar, sleeve drape & fabric volume...',
        progress: 0.50,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 700));

    // Step 3: Lighting and Warp
    onProgress?.call(
      const ProcessingStep(
        title: 'Harmonizing Light & Folds',
        description: 'Simulating ambient shadows and silk/cashmere drape...',
        progress: 0.75,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 750));

    // Step 4: Final High-Res Render
    onProgress?.call(
      const ProcessingStep(
        title: 'Finalizing Studio Render',
        description: 'Applying editorial finish and texture resolution...',
        progress: 0.95,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 500));

    // Select the best image representing the on-body garment result
    final resultImageUrl =
        variant.imageUrl ??
        (product.images.length > 1 ? product.images[1] : product.images.first);

    final result = TryOnResult(
      id: 'try_${DateTime.now().millisecondsSinceEpoch}',
      photo: photo,
      product: product,
      variant: variant,
      resultImageUrl: resultImageUrl,
      createdAt: DateTime.now(),
    );

    _cache[cacheKey] = result;
    _history.insert(0, result);

    onProgress?.call(
      const ProcessingStep(
        title: 'Ready',
        description: 'Virtual styling complete',
        progress: 1.0,
      ),
    );

    return result;
  }

  @override
  Future<List<TryOnResult>> getHistory() async {
    return List.unmodifiable(_history);
  }

  @override
  Future<void> saveResultToHistory(TryOnResult result) async {
    final idx = _history.indexWhere((h) => h.id == result.id);
    if (idx != -1) {
      _history[idx] = result;
    } else {
      _history.insert(0, result);
    }
  }

  @override
  Future<void> deleteHistoryItem(String id) async {
    _history.removeWhere((h) => h.id == id);
  }

  @override
  Future<void> clearHistory() async {
    _history.clear();
  }

  @override
  Future<bool> hasUserConsented() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsent) ?? false;
  }

  @override
  Future<void> setUserConsent(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConsent, consented);
  }

  @override
  Future<int> getRemainingCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCredits) ?? 15;
  }
}
