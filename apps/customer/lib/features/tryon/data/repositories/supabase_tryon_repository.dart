import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:clothsy_core/data/mappers/catalog_mappers.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_photo.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_session.dart';
import 'package:clothsy_core/features/tryon/domain/repositories/tryon_repository.dart';
import '../../../../core/supabase/supabase_errors.dart';

/// Clothsy AI Try-On against the backend: photos in the private
/// `tryon-photos` bucket, previews through the tryon-run Edge Function.
class SupabaseTryOnRepository implements TryOnRepository {
  final SupabaseClient _client;

  /// How often and how long a running preview is polled.
  final Duration pollEvery;
  final Duration giveUpAfter;

  SupabaseTryOnRepository(
    this._client, {
    this.pollEvery = const Duration(milliseconds: 1500),
    this.giveUpAfter = const Duration(seconds: 90),
  });

  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const TryOnException(
        'AUTH_REQUIRED',
        'Please sign in to use your own photos.',
      );
    }
    return uid;
  }

  TryOnException _error(Object e) {
    if (e is TryOnException) return e;
    if (e is StorageException &&
        (e.statusCode == '403' || e.statusCode == '401')) {
      return TryOnException('NO_CONSENT', ServerError('NO_CONSENT').message);
    }
    final server = ServerError.from(e);
    return TryOnException(server.code, server.message);
  }

  /// `tryon-photos/<uid>/x.jpg` → removed from its bucket (best effort; the
  /// hourly cleanup is the guarantee).
  Future<void> _removeFiles(Object? paths) async {
    if (paths is! List) return;
    final byBucket = <String, List<String>>{};
    for (final path in paths.whereType<String>()) {
      final slash = path.indexOf('/');
      if (slash < 0) continue;
      byBucket
          .putIfAbsent(path.substring(0, slash), () => [])
          .add(path.substring(slash + 1));
    }
    for (final entry in byBucket.entries) {
      try {
        await _client.storage.from(entry.key).remove(entry.value);
      } catch (_) {}
    }
  }

  TryOnPhoto _preset(Map<String, dynamic> row) => TryOnPhoto(
    id: row['id'] as String,
    label: row['label'] as String,
    imageUrl: row['image_url'] as String,
    isPreset: true,
    createdAt: DateTime(2026),
  );

  @override
  Future<List<TryOnPhoto>> getPresetPhotos() async {
    final rows = await _client
        .from('tryon_presets')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return rows.map(_preset).toList();
  }

  @override
  Future<List<TryOnPhoto>> getUserPhotos() async {
    if (_client.auth.currentUser == null) return [];
    final rows = await _client
        .from('tryon_photos')
        .select()
        .order('created_at', ascending: false);
    if (rows.isEmpty) return [];
    final signed = await _client.storage.from('tryon-photos').createSignedUrls([
      for (final r in rows) r['storage_path'] as String,
    ], 3600);
    final urls = {for (final s in signed) s.path: s.signedUrl};
    return [
      for (final r in rows)
        TryOnPhoto(
          id: r['id'] as String,
          label: r['label'] as String,
          imageUrl: urls[r['storage_path']] ?? '',
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          expiresAt: DateTime.parse(r['expires_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<TryOnPhoto> uploadUserPhoto(
    Uint8List bytes, {
    required String contentType,
    String label = 'My photo',
  }) async {
    final uid = _uid;
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => 'jpg',
    };
    final path = '$uid/${const Uuid().v4()}.$ext';
    try {
      await _client.storage
          .from('tryon-photos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      try {
        final row = await _client
            .from('tryon_photos')
            .insert({'storage_path': path, 'label': label})
            .select()
            .single();
        return TryOnPhoto(
          id: row['id'] as String,
          label: row['label'] as String,
          imageUrl: '',
          bytes: bytes,
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
        );
      } catch (e) {
        await _removeFiles(['tryon-photos/$path']);
        rethrow;
      }
    } catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<void> deleteUserPhoto(String id) async {
    final paths = await _client.rpc(
      'delete_tryon_photo',
      params: {'p_photo_id': id},
    );
    await _removeFiles(paths);
  }

  static const _steps = [
    ProcessingStep(
      title: 'Reading your photo',
      description: 'Finding pose and fit lines',
      progress: 0.25,
    ),
    ProcessingStep(
      title: 'Placing the piece',
      description: 'Matching the garment to your shape',
      progress: 0.5,
    ),
    ProcessingStep(
      title: 'Matching light and folds',
      description: 'Blending fabric, shadow and colour',
      progress: 0.75,
    ),
    ProcessingStep(
      title: 'Finishing your preview',
      description: 'Almost there',
      progress: 0.95,
    ),
  ];

  Future<String> _resultUrl(Map<String, dynamic> data) async {
    final url = data['result_url'] as String?;
    if (url != null && url.isNotEmpty) return url;
    final path = data['result_path'] as String?;
    if (path == null) {
      throw const TryOnException('FAILED', 'The preview is missing.');
    }
    return _client.storage.from('tryon-results').createSignedUrl(path, 3600);
  }

  @override
  Future<TryOnResult> runTryOn({
    required TryOnPhoto photo,
    required Product product,
    required ProductVariant variant,
    bool forceRefresh = false,
    void Function(ProcessingStep step)? onProgress,
  }) async {
    try {
      onProgress?.call(_steps.first);
      final started = await _client.functions.invoke(
        'tryon-run',
        body: {
          'action': 'run',
          'product_id': product.id,
          'variant_id': variant.id,
          if (photo.isPreset) 'preset_id': photo.id else 'photo_id': photo.id,
          'force': forceRefresh,
        },
      );
      var data = (started.data as Map).cast<String, dynamic>();
      final jobId = data['job_id'] as String;
      if (data['cached'] == true) {
        onProgress?.call(
          const ProcessingStep(
            title: 'Loaded your saved preview',
            description: 'Instant preview ready',
            progress: 1,
          ),
        );
      }

      final began = DateTime.now();
      var step = 1;
      while (data['status'] == 'processing') {
        if (DateTime.now().difference(began) > giveUpAfter) {
          throw const TryOnException(
            'TIMEOUT',
            'This preview is taking too long. Please try again.',
          );
        }
        await Future.delayed(pollEvery);
        if (step < _steps.length) onProgress?.call(_steps[step++]);
        final polled = await _client.functions.invoke(
          'tryon-run',
          body: {'action': 'poll', 'job_id': jobId},
        );
        data = (polled.data as Map).cast<String, dynamic>();
      }
      if (data['status'] != 'succeeded') {
        throw TryOnException(
          data['error_code'] as String? ?? 'FAILED',
          ServerError('TRYON_FAILED').message,
        );
      }

      return TryOnResult(
        id: jobId,
        photo: photo,
        product: product,
        variant: variant,
        resultImageUrl: await _resultUrl(data),
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<List<TryOnResult>> getHistory() async {
    if (_client.auth.currentUser == null) return [];
    final rows = await _client
        .from('tryon_jobs')
        .select(
          '*, product:products(${CatalogMappers.productSelect}), '
          'photo:tryon_photos(*), preset:tryon_presets(*)',
        )
        .eq('status', 'succeeded')
        .order('created_at', ascending: false)
        .limit(50);
    final results = <TryOnResult>[];
    for (final row in rows) {
      final productRow = row['product'] as Map<String, dynamic>?;
      if (productRow == null) continue;
      final product = CatalogMappers.product(productRow);
      final variant = product.variants
          .where((v) => v.id == row['variant_id'])
          .firstOrNull;
      if (variant == null) continue;
      final presetRow = row['preset'] as Map<String, dynamic>?;
      final photoRow = row['photo'] as Map<String, dynamic>?;
      final photo = presetRow != null
          ? _preset(presetRow)
          : TryOnPhoto(
              id: photoRow?['id'] as String? ?? '',
              label: photoRow?['label'] as String? ?? 'Your photo',
              imageUrl: '',
              createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
            );
      try {
        results.add(
          TryOnResult(
            id: row['id'] as String,
            photo: photo,
            product: product,
            variant: variant,
            resultImageUrl: await _resultUrl(row),
            createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
            rating: (row['rating'] as num?)?.toInt(),
            feedbackNote: row['feedback_note'] as String?,
          ),
        );
      } catch (_) {
        // A preview whose file is gone is simply left out.
      }
    }
    return results;
  }

  @override
  Future<void> saveResultToHistory(TryOnResult result) async {
    await _client
        .from('tryon_jobs')
        .update({'rating': result.rating, 'feedback_note': result.feedbackNote})
        .eq('id', result.id);
  }

  @override
  Future<void> deleteHistoryItem(String id) async {
    await _client
        .from('tryon_jobs')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  @override
  Future<void> clearHistory() async {
    if (_client.auth.currentUser == null) return;
    await _client
        .from('tryon_jobs')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .isFilter('deleted_at', null);
  }

  Future<Map<String, dynamic>> _status() async {
    if (_client.auth.currentUser == null) {
      return const {'consented': false, 'credits': 0};
    }
    final json = await _client.rpc('get_tryon_status');
    return (json as Map).cast<String, dynamic>();
  }

  @override
  Future<bool> hasUserConsented() async =>
      (await _status())['consented'] == true;

  @override
  Future<void> setUserConsent(bool consented) async {
    _uid;
    final json = await _client.rpc(
      'set_tryon_consent',
      params: {'p_granted': consented},
    );
    await _removeFiles((json as Map)['deleted_paths']);
  }

  @override
  Future<void> deleteAllTryOnData() async {
    if (_client.auth.currentUser == null) return;
    final paths = await _client.rpc('delete_my_tryon_data');
    await _removeFiles(paths);
  }

  @override
  Future<int> getRemainingCredits() async =>
      ((await _status())['credits'] as num?)?.toInt() ?? 0;
}
