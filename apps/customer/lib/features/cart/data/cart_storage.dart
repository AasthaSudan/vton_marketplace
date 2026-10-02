import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// One saved bag line: what to look up again, not prices (those are always
/// re-read from the catalogue, so a saved bag never shows stale prices).
class StoredBagLine {
  final String productId;
  final String variantId;
  final int quantity;

  const StoredBagLine(this.productId, this.variantId, this.quantity);

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'variant_id': variantId,
    'quantity': quantity,
  };

  static StoredBagLine? fromJson(Object? json) {
    if (json is! Map) return null;
    final product = json['product_id'];
    final variant = json['variant_id'];
    final quantity = json['quantity'];
    if (product is! String || variant is! String || quantity is! int) {
      return null;
    }
    return StoredBagLine(product, variant, quantity);
  }
}

/// Keeps the bag on the device so it survives restarts. [namespace] keeps
/// bags from different backends apart (mock vs a Supabase project).
class CartStorage {
  final String namespace;

  const CartStorage(this.namespace);

  String get _key => 'clothsy_bag_v1_$namespace';

  Future<(List<StoredBagLine>, String?)> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return (const <StoredBagLine>[], null);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final lines = (json['lines'] as List? ?? const [])
          .map(StoredBagLine.fromJson)
          .whereType<StoredBagLine>()
          .toList();
      return (lines, json['coupon'] as String?);
    } catch (_) {
      return (const <StoredBagLine>[], null);
    }
  }

  Future<void> save(List<StoredBagLine> lines, String? couponCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'lines': [for (final line in lines) line.toJson()],
          'coupon': couponCode,
        }),
      );
    } catch (_) {
      // The bag still works in memory if storage is unavailable.
    }
  }
}
