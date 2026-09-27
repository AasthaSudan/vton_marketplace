import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_shop/features/catalog/domain/entities/product.dart';
import '../../data/repositories/tryon_repository_impl.dart';
import '../../domain/entities/tryon_photo.dart';
import '../../domain/entities/tryon_session.dart';
import '../../domain/repositories/tryon_repository.dart';

final tryOnRepositoryProvider = Provider<TryOnRepository>((ref) {
  return TryOnRepositoryImpl();
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

class TryOnNotifier extends Notifier<TryOnSessionState> {
  @override
  TryOnSessionState build() {
    _initSession();
    return const TryOnSessionState();
  }

  Future<void> _initSession() async {
    final repo = ref.read(tryOnRepositoryProvider);
    final presets = await repo.getPresetPhotos();
    final consented = await repo.hasUserConsented();
    final credits = await repo.getRemainingCredits();

    if (!ref.mounted) return;
    state = state.copyWith(
      selectedPhoto: presets.isNotEmpty ? presets.first : null,
      hasConsented: consented,
      remainingCredits: credits,
    );
  }

  void selectPhoto(TryOnPhoto photo) {
    state = state.copyWith(
      selectedPhoto: photo,
      clearCurrentResult: true,
      clearError: true,
    );
  }

  void selectGarment(Product product, ProductVariant variant) {
    state = state.copyWith(
      selectedProduct: product,
      selectedVariant: variant,
      clearCurrentResult: true,
      clearError: true,
    );
  }

  Future<void> grantConsent() async {
    final repo = ref.read(tryOnRepositoryProvider);
    await repo.setUserConsent(true);
    if (!ref.mounted) return;
    state = state.copyWith(hasConsented: true);
  }

  Future<TryOnResult?> generateTryOn() async {
    if (state.selectedPhoto == null ||
        state.selectedProduct == null ||
        state.selectedVariant == null) {
      state = state.copyWith(
        errorMessage: 'Please select a photo and garment to style.',
      );
      return null;
    }

    state = state.copyWith(
      status: TryOnJobStatus.processing,
      clearError: true,
      clearCurrentResult: true,
    );

    try {
      final repo = ref.read(tryOnRepositoryProvider);
      final result = await repo.runTryOn(
        photo: state.selectedPhoto!,
        product: state.selectedProduct!,
        variant: state.selectedVariant!,
        onProgress: (step) {
          if (!ref.mounted) return;
          state = state.copyWith(currentStep: step);
        },
      );

      if (!ref.mounted) return null;
      state = state.copyWith(
        status: TryOnJobStatus.completed,
        currentResult: result,
      );

      // Add to global try-on history
      ref.read(tryOnHistoryProvider.notifier).addResult(result);
      return result;
    } catch (e) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        status: TryOnJobStatus.failed,
        errorMessage: 'Unable to render try-on: ${e.toString()}',
      );
      return null;
    }
  }

  void resetSession() {
    state = state.copyWith(
      status: TryOnJobStatus.idle,
      clearCurrentResult: true,
      clearError: true,
    );
  }

  void rateResult(int rating, [String? notes]) {
    if (state.currentResult != null) {
      final updated = state.currentResult!.copyWith(
        rating: rating,
        feedbackNote: notes,
      );
      state = state.copyWith(currentResult: updated);
      ref.read(tryOnRepositoryProvider).saveResultToHistory(updated);
      ref.read(tryOnHistoryProvider.notifier).addResult(updated);
    }
  }
}

final tryOnNotifierProvider =
    NotifierProvider<TryOnNotifier, TryOnSessionState>(TryOnNotifier.new);
