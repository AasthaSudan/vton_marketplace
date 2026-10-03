import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'seller_repository.dart';

/// The Seller Panel against the Clothsy backend (Supabase). Row level
/// security and the database functions decide what a seller may see and do;
/// this class only shapes requests and errors.
class SupabaseSellerRepository implements SellerRepository {
  final SupabaseClient _client;

  SupabaseSellerRepository(this._client);

  // ---------------------------------------------------------------------------
  // Errors
  // ---------------------------------------------------------------------------

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on SellerFailure {
      rethrow;
    } on PostgrestException catch (e) {
      throw _postgrest(e);
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('invalid login')) {
        throw const SellerFailure('INVALID_CREDENTIALS');
      }
      if (message.contains('already registered') ||
          message.contains('already exists')) {
        throw const SellerFailure('EMAIL_TAKEN');
      }
      if (message.contains('password')) {
        throw const SellerFailure('WEAK_PASSWORD');
      }
      throw SellerFailure('AUTH_ERROR', {'message': e.message});
    } on StorageException catch (e) {
      throw SellerFailure('UPLOAD_FAILED', {'message': e.message});
    } catch (e) {
      throw SellerFailure('NETWORK_ERROR', {'cause': '$e'});
    }
  }

  static SellerFailure _postgrest(PostgrestException e) {
    if (e.code == '23505') return const SellerFailure('DUPLICATE_SKU');
    if (e.code == '42501') return const SellerFailure('NOT_ALLOWED');
    Map<String, dynamic> details = const {};
    final raw = e.details;
    if (raw is Map) {
      details = raw.cast<String, dynamic>();
    } else if (raw is String && raw.startsWith('{')) {
      try {
        details = (jsonDecode(raw) as Map).cast<String, dynamic>();
      } on FormatException {
        // Plain-text detail.
      }
    }
    final code = RegExp(r'^[A-Z_]+$').hasMatch(e.message)
        ? e.message
        : 'SERVER_ERROR';
    return SellerFailure(code, details);
  }

  Future<dynamic> _rpc(String name, [Map<String, dynamic>? params]) =>
      _guard(() => _client.rpc(name, params: params));

  List<Map<String, dynamic>> _rows(dynamic data) =>
      (data as List).map((r) => (r as Map).cast<String, dynamic>()).toList();

  // ---------------------------------------------------------------------------
  // Account
  // ---------------------------------------------------------------------------

  @override
  Stream<bool> get signedInChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  String? get userEmail => _client.auth.currentUser?.email;

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() async {
        await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
      });

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => _guard(() async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
    // Hosted projects confirm the email first.
    if (res.session == null) throw const SellerFailure('CONFIRM_EMAIL');
  });

  @override
  Future<void> signOut() => _client.auth.signOut();

  // ---------------------------------------------------------------------------
  // Store and verification
  // ---------------------------------------------------------------------------

  @override
  Future<List<SellerContext>> mySellers() async =>
      _rows(await _rpc('my_sellers')).map(SellerContext.fromJson).toList();

  @override
  Future<String> registerSeller(String brandName) async {
    final res = await _rpc('register_seller', {'p_brand_name': brandName});
    return (res as Map)['seller_id'] as String;
  }

  @override
  Future<SellerApplication> application(String sellerId) => _guard(() async {
    final row = await _client
        .from('seller_applications')
        .select()
        .eq('seller_id', sellerId)
        .single();
    return SellerApplication.fromJson(row);
  });

  @override
  Future<void> saveApplication(
    String sellerId,
    SellerApplication application,
  ) => _guard(() async {
    await _client
        .from('seller_applications')
        .update(application.toUpdateJson())
        .eq('seller_id', sellerId);
  });

  @override
  Future<BankAccount?> bankAccount(String sellerId) async {
    final res = await _rpc('get_seller_bank_account', {
      'p_seller_id': sellerId,
    });
    return res == null
        ? null
        : BankAccount.fromJson((res as Map).cast<String, dynamic>());
  }

  @override
  Future<BankAccount> setBankAccount(
    String sellerId, {
    required String accountHolder,
    required String accountNumber,
    required String ifsc,
  }) async {
    final res = await _rpc('set_seller_bank_account', {
      'p_seller_id': sellerId,
      'p_account_holder': accountHolder,
      'p_account_number': accountNumber,
      'p_ifsc': ifsc,
    });
    return BankAccount.fromJson((res as Map).cast<String, dynamic>());
  }

  @override
  Future<List<SellerDocument>> documents(String sellerId) => _guard(() async {
    final rows = await _client
        .from('seller_documents')
        .select()
        .eq('seller_id', sellerId)
        .order('created_at', ascending: true);
    return rows.map(SellerDocument.fromJson).toList();
  });

  static String _extension(String fileName, String contentType) {
    final dot = fileName.lastIndexOf('.');
    if (dot > 0 && dot < fileName.length - 1) {
      return fileName.substring(dot + 1).toLowerCase();
    }
    return switch (contentType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  @override
  Future<void> uploadDocument(
    String sellerId, {
    required String kind,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) => _guard(() async {
    final path =
        '$sellerId/$kind-${DateTime.now().millisecondsSinceEpoch}'
        '.${_extension(fileName, contentType)}';
    await _client.storage
        .from('seller-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    try {
      await _client.from('seller_documents').insert({
        'seller_id': sellerId,
        'kind': kind,
        'storage_path': path,
        'file_name': fileName,
      });
    } catch (_) {
      await _client.storage.from('seller-documents').remove([path]);
      rethrow;
    }
  });

  @override
  Future<void> deleteDocument(SellerDocument document) => _guard(() async {
    await _client.from('seller_documents').delete().eq('id', document.id);
    await _client.storage.from('seller-documents').remove([
      document.storagePath,
    ]);
  });

  @override
  Future<void> submitApplication(String sellerId) async {
    await _rpc('submit_seller_application', {'p_seller_id': sellerId});
  }

  @override
  Future<List<ApplicationEvent>> applicationHistory(String sellerId) =>
      _guard(() async {
        final rows = await _client
            .from('seller_application_events')
            .select()
            .eq('seller_id', sellerId)
            .order('id', ascending: true);
        return rows.map(ApplicationEvent.fromJson).toList();
      });

  // ---------------------------------------------------------------------------
  // Storefront
  // ---------------------------------------------------------------------------

  @override
  Future<Storefront> storefront(String sellerId) => _guard(() async {
    final row = await _client
        .from('sellers')
        .select(
          'name, tagline, story, logo_url, banner_url, city, dispatch_days, '
          'return_window_days, instagram_url, website_url, support_email, '
          'return_policy, shipping_policy',
        )
        .eq('id', sellerId)
        .single();
    return Storefront.fromJson(row);
  });

  @override
  Future<void> saveStorefront(String sellerId, Storefront storefront) =>
      _guard(() async {
        await _client
            .from('sellers')
            .update(storefront.toUpdateJson())
            .eq('id', sellerId);
      });

  @override
  Future<String> uploadImage(
    String sellerId, {
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) => _guard(() async {
    final path =
        'sellers/$sellerId/${DateTime.now().microsecondsSinceEpoch}'
        '.${_extension(fileName, contentType)}';
    await _client.storage
        .from('catalog')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return _client.storage.from('catalog').getPublicUrl(path);
  });

  @override
  Future<List<SellerCollection>> collections(String sellerId) =>
      _guard(() async {
        final rows = await _client
            .from('seller_collections')
            .select()
            .eq('seller_id', sellerId)
            .order('position', ascending: true);
        return rows.map(SellerCollection.fromJson).toList();
      });

  @override
  Future<void> saveCollection(
    String sellerId, {
    String? id,
    required String title,
    required String description,
    required List<String> productIds,
    required bool isVisible,
  }) => _guard(() async {
    final row = {
      'title': title,
      'description': description,
      'product_ids': productIds,
      'is_visible': isVisible,
    };
    if (id == null) {
      await _client.from('seller_collections').insert({
        ...row,
        'seller_id': sellerId,
      });
    } else {
      await _client.from('seller_collections').update(row).eq('id', id);
    }
  });

  @override
  Future<void> deleteCollection(String id) => _guard(() async {
    await _client.from('seller_collections').delete().eq('id', id);
  });

  // ---------------------------------------------------------------------------
  // Products and stock
  // ---------------------------------------------------------------------------

  static const _productColumns = '*, variants:product_variants(*)';

  @override
  Future<List<SellerProduct>> products(String sellerId) => _guard(() async {
    final rows = await _client
        .from('products')
        .select(_productColumns)
        .eq('seller_id', sellerId)
        .order('updated_at', ascending: false);
    return rows.map(SellerProduct.fromJson).toList();
  });

  @override
  Future<SellerProduct> product(String productId) => _guard(() async {
    final row = await _client
        .from('products')
        .select(_productColumns)
        .eq('id', productId)
        .single();
    return SellerProduct.fromJson(row);
  });

  @override
  Future<String> createProduct(String sellerId, ProductDraft draft) =>
      _guard(() async {
        final row = await _client
            .from('products')
            .insert({...draft.toJson(), 'seller_id': sellerId})
            .select('id')
            .single();
        return row['id'] as String;
      });

  @override
  Future<void> updateProduct(String productId, ProductDraft draft) => _guard(
    () async {
      await _client.from('products').update(draft.toJson()).eq('id', productId);
    },
  );

  @override
  Future<void> deleteProduct(String productId) => _guard(() async {
    final rows = await _client
        .from('products')
        .delete()
        .eq('id', productId)
        .select('id');
    if (rows.isEmpty) throw const SellerFailure('NOT_DELETABLE');
  });

  @override
  Future<void> addVariant(String productId, VariantDraft draft) =>
      _guard(() async {
        await _client.from('product_variants').insert({
          ...draft.toJson(),
          'product_id': productId,
        });
      });

  @override
  Future<void> updateVariant(String variantId, VariantDraft draft) =>
      _guard(() async {
        await _client
            .from('product_variants')
            .update(draft.toJson(includeStock: false))
            .eq('id', variantId);
      });

  @override
  Future<void> deleteVariant(String variantId) => _guard(() async {
    final rows = await _client
        .from('product_variants')
        .delete()
        .eq('id', variantId)
        .select('id');
    if (rows.isEmpty) throw const SellerFailure('NOT_DELETABLE');
  });

  @override
  Future<void> submitProduct(String productId) async {
    await _rpc('submit_product', {'p_product_id': productId});
  }

  @override
  Future<void> setListed(String productId, bool listed) async {
    await _rpc('set_product_listed', {
      'p_product_id': productId,
      'p_listed': listed,
    });
  }

  @override
  Future<int> adjustStock(String variantId, int delta, {String? note}) async {
    final res = await _rpc('adjust_stock', {
      'p_variant_id': variantId,
      'p_delta': delta,
      'p_note': note,
    });
    return (res as num).toInt();
  }

  @override
  Future<({int updated, int unchanged})> bulkSetStock(
    String sellerId,
    List<({String sku, int stock})> rows,
  ) async {
    final res =
        await _rpc('bulk_set_stock', {
              'p_seller_id': sellerId,
              'p_rows': [
                for (final r in rows) {'sku': r.sku, 'stock': r.stock},
              ],
            })
            as Map;
    return (
      updated: (res['updated'] as num).toInt(),
      unchanged: (res['unchanged'] as num).toInt(),
    );
  }

  @override
  Future<List<StockMovement>> stockHistory(
    String sellerId, {
    int limit = 100,
  }) => _guard(() async {
    final rows = await _client
        .from('inventory_movements')
        .select(
          'id, delta, reason, note, created_at, '
          'variant:product_variants(sku, title, product:products(title))',
        )
        .eq('seller_id', sellerId)
        .order('id', ascending: false)
        .limit(limit);
    return rows.map(StockMovement.fromJson).toList();
  });

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  @override
  Future<List<SellerOrder>> orders(String sellerId) => _guard(() async {
    final rows = await _client
        .from('seller_orders')
        .select('*, items:order_items(*), shipments(*)')
        .eq('seller_id', sellerId)
        .neq('status', 'pending_payment')
        .order('created_at', ascending: false)
        .limit(300);
    return rows.map(SellerOrder.fromJson).toList();
  });

  @override
  Future<void> acceptOrder(String sellerOrderId) async {
    await _rpc('seller_accept_order', {'p_seller_order_id': sellerOrderId});
  }

  @override
  Future<String> packOrder(String sellerOrderId) async {
    final res = await _rpc('seller_pack_order', {
      'p_seller_order_id': sellerOrderId,
    });
    return (res as Map)['invoice_number'] as String;
  }

  @override
  Future<void> shipOrder(
    String sellerOrderId, {
    required String carrier,
    required String trackingNumber,
    String? trackingUrl,
  }) async {
    await _rpc('seller_ship_order', {
      'p_seller_order_id': sellerOrderId,
      'p_carrier': carrier,
      'p_tracking_number': trackingNumber,
      'p_tracking_url': trackingUrl,
    });
  }

  @override
  Future<void> markDelivered(String sellerOrderId) async {
    await _rpc('advance_seller_order', {
      'p_seller_order_id': sellerOrderId,
      'p_to_status': 'delivered',
    });
  }

  @override
  Future<void> cancelOrder(String sellerOrderId, String reason) async {
    await _rpc('seller_cancel_order', {
      'p_seller_order_id': sellerOrderId,
      'p_reason': reason,
    });
  }

  @override
  Future<Map<String, dynamic>> invoice(String sellerOrderId) async =>
      ((await _rpc('seller_order_invoice', {
                'p_seller_order_id': sellerOrderId,
              }))
              as Map)
          .cast<String, dynamic>();

  // ---------------------------------------------------------------------------
  // Money and insights
  // ---------------------------------------------------------------------------

  @override
  Future<List<Settlement>> settlements(String sellerId) => _guard(() async {
    final rows = await _client
        .from('seller_settlements')
        .select()
        .eq('seller_id', sellerId)
        .order('delivered_at', ascending: false);
    return rows.map(Settlement.fromJson).toList();
  });

  @override
  Future<List<Payout>> payouts(String sellerId) => _guard(() async {
    final rows = await _client
        .from('payouts')
        .select()
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);
    return rows.map(Payout.fromJson).toList();
  });

  @override
  Future<List<Adjustment>> adjustments(String sellerId) => _guard(() async {
    final rows = await _client
        .from('seller_adjustments')
        .select()
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);
    return rows.map(Adjustment.fromJson).toList();
  });

  @override
  Future<SellerDashboard> dashboard(String sellerId) async =>
      SellerDashboard.fromJson(
        ((await _rpc('seller_dashboard', {'p_seller_id': sellerId})) as Map)
            .cast<String, dynamic>(),
      );

  @override
  Future<List<SalesDay>> salesDaily(String sellerId, {int days = 30}) async =>
      _rows(
        await _rpc('seller_sales_daily', {
          'p_seller_id': sellerId,
          'p_days': days,
        }),
      ).map(SalesDay.fromJson).toList();

  @override
  Future<List<TopProduct>> topProducts(
    String sellerId, {
    int days = 30,
  }) async => _rows(
    await _rpc('seller_top_products', {
      'p_seller_id': sellerId,
      'p_days': days,
    }),
  ).map(TopProduct.fromJson).toList();

  @override
  Future<List<TryOnInsight>> tryOnInsights(
    String sellerId, {
    int days = 30,
  }) async => _rows(
    await _rpc('seller_tryon_insights', {
      'p_seller_id': sellerId,
      'p_days': days,
    }),
  ).map(TryOnInsight.fromJson).toList();
}
