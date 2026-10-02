import 'package:clothsy_core/features/cart/domain/entities/coupon.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';

class CartLineItem {
  final String id;
  final Product product;
  final ProductVariant variant;
  final int quantity;

  const CartLineItem({
    required this.id,
    required this.product,
    required this.variant,
    this.quantity = 1,
  });

  int get lineTotal => variant.price * quantity;

  CartLineItem copyWith({
    String? id,
    Product? product,
    ProductVariant? variant,
    int? quantity,
  }) {
    return CartLineItem(
      id: id ?? this.id,
      product: product ?? this.product,
      variant: variant ?? this.variant,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// One seller's slice of the bag. Clothsy quietly groups the bag by seller
/// (Blueprint section 27): each group becomes its own seller order and
/// shipment, so shipping is charged — or waived — per group.
class SellerBagGroup {
  final String sellerId;
  final String sellerName;
  final List<CartLineItem> items;
  final int shippingThreshold;

  const SellerBagGroup({
    required this.sellerId,
    required this.sellerName,
    required this.items,
    required this.shippingThreshold,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  /// Shipping for this shipment: free once the group reaches the threshold.
  int get shippingFee {
    if (subtotal == 0) return 0;
    return subtotal >= shippingThreshold ? 0 : CartSummary.standardShippingFee;
  }

  /// Still to add from this seller for free shipping (0 when already free).
  int get amountToFreeShipping {
    final gap = shippingThreshold - subtotal;
    return gap > 0 ? gap : 0;
  }

  int get total => subtotal + shippingFee;
}

/// Bag totals. All amounts are integer paise (₹1 = 100 paise).
class CartSummary {
  final List<CartLineItem> items;
  final String? couponCode;

  /// The validated rule behind [couponCode], used to recompute the discount
  /// as the bag changes.
  final CouponRule? coupon;
  final int discountAmount;

  /// Per-seller threshold (a seller's shipment ships free at or above it).
  final int shippingThreshold;

  /// Flat shipping charge (paise) for a shipment under [shippingThreshold].
  static const int standardShippingFee = 15000;

  const CartSummary({
    this.items = const [],
    this.couponCode,
    this.coupon,
    this.discountAmount = 0,
    this.shippingThreshold = 199900,
  });

  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  /// The bag grouped by seller, in the order sellers were first added.
  List<SellerBagGroup> get sellerGroups {
    final byId = <String, List<CartLineItem>>{};
    final names = <String, String>{};
    for (final item in items) {
      final id = item.product.sellerId;
      byId.putIfAbsent(id, () => []).add(item);
      names.putIfAbsent(id, () => item.product.brand);
    }
    return [
      for (final entry in byId.entries)
        SellerBagGroup(
          sellerId: entry.key,
          sellerName: names[entry.key]!,
          items: entry.value,
          shippingThreshold: shippingThreshold,
        ),
    ];
  }

  /// Number of separate shipments (one per seller).
  int get shipmentCount => sellerGroups.length;

  /// Sum of every shipment's shipping fee.
  int get shippingFee =>
      sellerGroups.fold(0, (sum, group) => sum + group.shippingFee);

  int get total {
    final t = subtotal - discountAmount + shippingFee;
    return t < 0 ? 0 : t;
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}
