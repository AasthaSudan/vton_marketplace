import 'dart:async';
import 'dart:typed_data';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_photo.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_session.dart';
import 'package:clothsy_core/features/tryon/domain/repositories/tryon_repository.dart';

class MockTryOnRepository implements TryOnRepository {
  static const String _keyConsent = 'clothsy_tryon_consent_v1';
  static const String _keyCredits = 'clothsy_tryon_credits_v1';

  /// AI previews a new shopper starts with (the server uses the same).
  static const int startingCredits = 15;

  /// Shopper photos are deleted automatically after this long.
  static const Duration retention = Duration(days: 30);

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

  MockTryOnRepository() {
    // Seed initial demo history
    _seedInitialHistory();
  }

  void _seedInitialHistory() {
    // A real catalogue piece, so "Tried on" badges point at the right product.
    const blazerImage =
        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=900&auto=format&fit=crop&q=80';
    const demoVariant = ProductVariant(
      id: 'v_blazer_lavender',
      title: 'Soft Lavender / M',
      size: 'M',
      colorName: 'Soft Lavender',
      colorHex: '0xFFB9A6E0',
      price: 799900,
      originalPrice: 999900,
      imageUrl: blazerImage,
    );

    const demoProduct = Product(
      id: 'p_lavender_blazer',
      handle: 'lavender-blazer',
      title: 'Lavender Blazer',
      sellerId: 'sel_noor',
      brand: 'Noor Atelier',
      category: 'Women',
      description: 'Tailored stretch-twill blazer with notch lapels.',
      price: 799900,
      originalPrice: 999900,
      images: [blazerImage],
      availableSizes: ['S', 'M', 'L', 'XL'],
      variants: [demoVariant],
    );

    final preset = _presets.first;
    final initialResult = TryOnResult(
      id: 'try_init_1',
      photo: preset,
      product: demoProduct,
      variant: demoVariant,
      resultImageUrl: blazerImage,
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
  Future<TryOnPhoto> uploadUserPhoto(
    Uint8List bytes, {
    required String contentType,
    String label = 'My photo',
  }) async {
    if (!await hasUserConsented()) {
      throw const TryOnException('NO_CONSENT', ClothsyCopy.tryOnNeedsConsent);
    }
    final now = DateTime.now();
    final photo = TryOnPhoto(
      id: 'user_photo_${now.microsecondsSinceEpoch}',
      label: label.isEmpty ? 'My photo' : label,
      imageUrl: '',
      bytes: bytes,
      createdAt: now,
      expiresAt: now.add(retention),
    );
    _userPhotos.insert(0, photo);
    return photo;
  }

  @override
  Future<void> deleteUserPhoto(String id) async {
    _userPhotos.removeWhere((p) => p.id == id);
    _cache.removeWhere((key, _) => key.startsWith('${id}_'));
    _history.removeWhere((h) => h.photo.id == id);
  }

  @override
  Future<TryOnResult> runTryOn({
    required TryOnPhoto photo,
    required Product product,
    required ProductVariant variant,
    bool forceRefresh = false,
    void Function(ProcessingStep step)? onProgress,
  }) async {
    if (!product.isTryonEligible) {
      throw const TryOnException('NOT_ELIGIBLE', ClothsyCopy.tryOnUnsupported);
    }
    if (!photo.isPreset && !await hasUserConsented()) {
      throw const TryOnException('NO_CONSENT', ClothsyCopy.tryOnNeedsConsent);
    }

    final cacheKey = '${photo.id}_${product.id}_${variant.id}';

    // The same photo + variant is answered instantly, without a credit.
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      onProgress?.call(
        const ProcessingStep(
          title: 'Loaded your saved preview',
          description: 'Instant preview ready',
          progress: 1.0,
        ),
      );
      return cached;
    }

    final credits = await getRemainingCredits();
    if (credits <= 0) {
      throw const TryOnException('NO_CREDITS', ClothsyCopy.tryOnNoCredits);
    }
    await _setCredits(credits - 1);

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
    // Withdrawing consent removes the shopper's photos and previews.
    if (!consented) await deleteAllTryOnData();
  }

  @override
  Future<void> deleteAllTryOnData() async {
    final ids = _userPhotos.map((p) => p.id).toSet();
    _userPhotos.clear();
    _history.removeWhere((h) => ids.contains(h.photo.id) || !h.photo.isPreset);
    _cache.removeWhere((_, result) => !result.photo.isPreset);
  }

  @override
  Future<int> getRemainingCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCredits) ?? startingCredits;
  }

  Future<void> _setCredits(int credits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCredits, credits);
  }
}
