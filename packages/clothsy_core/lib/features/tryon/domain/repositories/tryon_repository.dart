import 'dart:typed_data';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import '../entities/tryon_photo.dart';
import '../entities/tryon_session.dart';

/// Why a try-on preview could not be made, with a message to show. Try-On
/// never blocks shopping: every case leaves size help and Add to bag open.
class TryOnException implements Exception {
  /// `NO_CONSENT`, `NO_CREDITS`, `NOT_ELIGIBLE`, `PHOTO_UNSUITABLE`,
  /// `UNAVAILABLE` or `FAILED`.
  final String code;
  final String message;

  const TryOnException(this.code, this.message);

  @override
  String toString() => message;
}

abstract class TryOnRepository {
  Future<List<TryOnPhoto>> getPresetPhotos();
  Future<List<TryOnPhoto>> getUserPhotos();

  /// Stores the shopper's own photo privately. Needs their consent first.
  Future<TryOnPhoto> uploadUserPhoto(
    Uint8List bytes, {
    required String contentType,
    String label,
  });
  Future<void> deleteUserPhoto(String id);

  /// Creates a preview of [variant] on [photo]. The same photo + variant is
  /// answered from the cache unless [forceRefresh] asks for a new one.
  /// Throws [TryOnException].
  Future<TryOnResult> runTryOn({
    required TryOnPhoto photo,
    required Product product,
    required ProductVariant variant,
    bool forceRefresh = false,
    void Function(ProcessingStep step)? onProgress,
  });
  Future<List<TryOnResult>> getHistory();
  Future<void> saveResultToHistory(TryOnResult result);
  Future<void> deleteHistoryItem(String id);
  Future<void> clearHistory();
  Future<bool> hasUserConsented();

  /// Withdrawing consent also deletes every photo and preview.
  Future<void> setUserConsent(bool consented);

  /// "Delete my try-on photos": every shopper photo and preview, now.
  Future<void> deleteAllTryOnData();
  Future<int> getRemainingCredits();
}
