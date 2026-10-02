import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import '../../data/repositories/mock_tryon_repository.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_photo.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_session.dart';
import 'package:clothsy_core/features/tryon/domain/repositories/tryon_repository.dart';

final tryOnRepositoryProvider = Provider<TryOnRepository>((ref) {
  return MockTryOnRepository();
});

final tryOnPresetsProvider = FutureProvider<List<TryOnPhoto>>((ref) async {
  final repo = ref.read(tryOnRepositoryProvider);
  return repo.getPresetPhotos();
});

class TryOnHistoryNotifier extends Notifier<List<TryOnResult>> {
  @override
  List<TryOnResult> build() {
    _loadHistory();
    return [];
  }

  Future<void> _loadHistory() async {
    final repo = ref.read(tryOnRepositoryProvider);
    final history = await repo.getHistory();
    if (!ref.mounted) return;
    state = history;
  }

  Future<void> reload() => _loadHistory();

  Future<void> deleteItem(String id) async {
    final repo = ref.read(tryOnRepositoryProvider);
    await repo.deleteHistoryItem(id);
    if (!ref.mounted) return;
    state = state.where((item) => item.id != id).toList();
  }

  Future<void> clearAll() async {
    final repo = ref.read(tryOnRepositoryProvider);
    await repo.clearHistory();
    if (!ref.mounted) return;
    state = [];
  }

  void addResult(TryOnResult result) {
    state = [result, ...state.where((r) => r.id != result.id)];
  }
}

final tryOnHistoryProvider =
    NotifierProvider<TryOnHistoryNotifier, List<TryOnResult>>(
      TryOnHistoryNotifier.new,
    );

/// Set of all product IDs that the shopper has already tried on with Clothsy AI.
final triedOnProductIdsProvider = Provider<Set<String>>((ref) {
  final history = ref.watch(tryOnHistoryProvider);
  return history.map((r) => r.product.id).toSet();
});

/// The first variant that can actually be bought, or the first one at all.
ProductVariant defaultVariantOf(Product product) {
  return product.variants.firstWhere(
    (v) => v.isAvailable,
    orElse: () => product.variants.first,
  );
}

class TryOnNotifier extends Notifier<TryOnSessionState> {
  /// Bumped whenever a job is started or cancelled, so a cancelled job's
  /// late answer is thrown away instead of shown.
  int _job = 0;

  @override
  TryOnSessionState build() {
    _initSession();
    return const TryOnSessionState();
  }

  TryOnRepository get _repo => ref.read(tryOnRepositoryProvider);

  Future<void> _initSession() async {
    final repo = _repo;
    final presets = await repo.getPresetPhotos();
    final consented = await repo.hasUserConsented();
    final credits = await repo.getRemainingCredits();

    if (!ref.mounted) return;
    state = state.copyWith(
      selectedPhoto:
          state.selectedPhoto ?? (presets.isNotEmpty ? presets.first : null),
      hasConsented: consented,
      remainingCredits: credits,
    );
  }

  void selectPhoto(TryOnPhoto photo) {
    state = state.copyWith(
      selectedPhoto: photo,
      status: TryOnJobStatus.idle,
      clearCurrentResult: true,
      clearError: true,
    );
  }

  void selectGarment(Product product, [ProductVariant? variant]) {
    state = state.copyWith(
      selectedProduct: product,
      selectedVariant: variant ?? defaultVariantOf(product),
      status: TryOnJobStatus.idle,
      clearCurrentResult: true,
      clearError: true,
    );
  }

  /// Switches colour / variant of the selected garment (Blueprint: the
  /// shopper always sees exactly which variant is being visualised).
  void selectVariant(ProductVariant variant) {
    state = state.copyWith(
      selectedVariant: variant,
      status: TryOnJobStatus.idle,
      clearCurrentResult: true,
      clearError: true,
    );
  }

  Future<void> grantConsent() async {
    final repo = _repo;
    await repo.setUserConsent(true);
    if (!ref.mounted) return;
    state = state.copyWith(hasConsented: true);
  }

  /// Withdraws consent: every shopper photo and preview is deleted, and the
  /// session falls back to a model photo.
  Future<void> revokeConsent() async {
    final repo = _repo;
    await repo.setUserConsent(false);
    final presets = await repo.getPresetPhotos();
    if (!ref.mounted) return;
    state = TryOnSessionState(
      selectedPhoto: presets.isNotEmpty ? presets.first : null,
      selectedProduct: state.selectedProduct,
      selectedVariant: state.selectedVariant,
      remainingCredits: state.remainingCredits,
    );
    await ref.read(tryOnHistoryProvider.notifier).reload();
  }

  /// "Delete my try-on photos" without withdrawing consent.
  Future<void> deleteMyPhotos() async {
    final repo = _repo;
    await repo.deleteAllTryOnData();
    final presets = await repo.getPresetPhotos();
    if (!ref.mounted) return;
    if (state.selectedPhoto?.isPreset == false) {
      state = state.copyWith(
        selectedPhoto: presets.isNotEmpty ? presets.first : null,
        status: TryOnJobStatus.idle,
        clearCurrentResult: true,
      );
    }
    await ref.read(tryOnHistoryProvider.notifier).reload();
  }

  /// Saves the shopper's own photo (consent required) and selects it.
  /// Returns an error message, or null on success.
  Future<String?> useOwnPhoto(Uint8List bytes, String contentType) async {
    final repo = _repo;
    state = state.copyWith(
      status: TryOnJobStatus.validatingPhoto,
      clearError: true,
    );
    try {
      final photo = await repo.uploadUserPhoto(bytes, contentType: contentType);
      if (!ref.mounted) return null;
      selectPhoto(photo);
      return null;
    } on TryOnException catch (e) {
      if (ref.mounted) state = state.copyWith(status: TryOnJobStatus.idle);
      return e.message;
    } catch (_) {
      if (ref.mounted) state = state.copyWith(status: TryOnJobStatus.idle);
      return ClothsyCopy.tryOnFailed;
    }
  }

  /// Creates the preview. [regenerate] asks for a fresh one instead of the
  /// cached result (uses a credit).
  Future<TryOnResult?> generateTryOn({bool regenerate = false}) async {
    final repo = _repo;
    final photo = state.selectedPhoto;
    final product = state.selectedProduct;
    final variant = state.selectedVariant;
    if (photo == null || product == null || variant == null) {
      state = state.copyWith(
        errorMessage: 'Pick a photo and a piece to try on.',
      );
      return null;
    }

    final job = ++_job;
    state = state.copyWith(
      status: TryOnJobStatus.processing,
      clearError: true,
      clearCurrentResult: true,
    );

    try {
      final result = await repo.runTryOn(
        photo: photo,
        product: product,
        variant: variant,
        forceRefresh: regenerate,
        onProgress: (step) {
          if (!ref.mounted || job != _job) return;
          state = state.copyWith(currentStep: step);
        },
      );
      final credits = await repo.getRemainingCredits();

      if (!ref.mounted) return null;
      if (job != _job) {
        // Cancelled while it was running: drop the late result.
        await repo.deleteHistoryItem(result.id);
        return null;
      }
      state = state.copyWith(
        status: TryOnJobStatus.completed,
        currentResult: result,
        remainingCredits: credits,
      );
      ref.read(tryOnHistoryProvider.notifier).addResult(result);
      return result;
    } on TryOnException catch (e) {
      if (!ref.mounted || job != _job) return null;
      state = state.copyWith(
        status: TryOnJobStatus.failed,
        errorMessage: e.message,
      );
      return null;
    } catch (_) {
      if (!ref.mounted || job != _job) return null;
      state = state.copyWith(
        status: TryOnJobStatus.failed,
        errorMessage: ClothsyCopy.tryOnFailed,
      );
      return null;
    }
  }

  /// Stops waiting for the current job; its result, if any, is discarded.
  void cancel() {
    _job++;
    resetSession();
  }

  void resetSession() {
    state = state.copyWith(
      status: TryOnJobStatus.idle,
      clearCurrentResult: true,
      clearError: true,
    );
  }

  /// Saves the current look to the shopper's history with a rating.
  void saveLook([int rating = 5]) {
    final current = state.currentResult;
    if (current == null) return;
    final updated = current.copyWith(rating: rating);
    state = state.copyWith(currentResult: updated);
    _repo.saveResultToHistory(updated);
    ref.read(tryOnHistoryProvider.notifier).addResult(updated);
  }
}

final tryOnNotifierProvider =
    NotifierProvider<TryOnNotifier, TryOnSessionState>(TryOnNotifier.new);
