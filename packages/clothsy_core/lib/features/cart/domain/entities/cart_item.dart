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

/// Bag totals. All amounts are integer paise (₹1 = 100 paise).
class CartSummary {
  final List<CartLineItem> items;
  final String? couponCode;
  final int discountAmount;
  final int shippingThreshold;

  /// Flat shipping charge (paise) when the bag is under [shippingThreshold].
  static const int standardShippingFee = 15000;

  const CartSummary({
    this.items = const [],
    this.couponCode,
    this.discountAmount = 0,
    this.shippingThreshold = 199900,
  });

  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  int get shippingFee {
    if (subtotal == 0) return 0;
    return subtotal >= shippingThreshold ? 0 : standardShippingFee;
  }

  int get total {
    final t = subtotal - discountAmount + shippingFee;
    return t < 0 ? 0 : t;
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}
