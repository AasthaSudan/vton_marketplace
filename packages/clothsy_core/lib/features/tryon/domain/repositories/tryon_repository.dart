import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import '../entities/tryon_photo.dart';
import '../entities/tryon_session.dart';

abstract class TryOnRepository {
  Future<List<TryOnPhoto>> getPresetPhotos();
  Future<List<TryOnPhoto>> getUserPhotos();
  Future<TryOnPhoto> saveUserPhoto(String imageUrl, String label);
  Future<void> deleteUserPhoto(String id);
  Future<TryOnResult> runTryOn({
    required TryOnPhoto photo,
    required Product product,
    required ProductVariant variant,
    void Function(ProcessingStep step)? onProgress,
  });
  Future<List<TryOnResult>> getHistory();
  Future<void> saveResultToHistory(TryOnResult result);
  Future<void> deleteHistoryItem(String id);
  Future<void> clearHistory();
  Future<bool> hasUserConsented();
  Future<void> setUserConsent(bool consented);
  Future<int> getRemainingCredits();
}
