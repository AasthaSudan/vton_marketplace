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

  num get lineTotal => variant.price * quantity;

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

class CartSummary {
  final List<CartLineItem> items;
  final String? couponCode;
  final num discountAmount;
  final num shippingThreshold;

  const CartSummary({
    this.items = const [],
    this.couponCode,
    this.discountAmount = 0,
    this.shippingThreshold = 1999,
  });

  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);

  num get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  num get shippingFee {
    if (subtotal == 0) return 0;
    return subtotal >= shippingThreshold ? 0 : 150;
  }

  num get total {
    final t = subtotal - discountAmount + shippingFee;
    return t < 0 ? 0 : t;
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}
