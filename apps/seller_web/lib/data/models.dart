// What the Seller Panel works with, read from the Clothsy backend's rows and
// functions. Money is integer paise throughout.

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

List<String> _strings(Object? value) =>
    (value as List? ?? const []).map((e) => e as String).toList();

/// A store the signed-in user works for (my_sellers).
class SellerContext {
  final String sellerId;
  final String handle;
  final String name;

  /// pending | approved | suspended
  final String status;

  /// owner | manager | staff
  final String role;

  /// draft | submitted | needs_info | approved | rejected
  final String applicationStatus;
  final String? reviewNote;

  /// What still blocks submitting the application.
  final List<String> missing;

  const SellerContext({
    required this.sellerId,
    required this.handle,
    required this.name,
    required this.status,
    required this.role,
    required this.applicationStatus,
    this.reviewNote,
    this.missing = const [],
  });

  factory SellerContext.fromJson(Map<String, dynamic> json) => SellerContext(
    sellerId: json['seller_id'] as String,
    handle: json['handle'] as String,
    name: json['name'] as String,
    status: json['status'] as String,
    role: json['role'] as String,
    applicationStatus: json['application_status'] as String? ?? 'draft',
    reviewNote: json['review_note'] as String?,
    missing: _strings(json['missing']),
  );

  bool get isApproved => status == 'approved';
  bool get canEditApplication =>
      applicationStatus == 'draft' || applicationStatus == 'needs_info';
  bool get isOwner => role == 'owner';
  bool get canManage => role == 'owner' || role == 'manager';
}

const businessTypes = {
  'individual': 'Individual',
  'proprietorship': 'Sole proprietorship',
  'partnership': 'Partnership',
  'llp': 'LLP',
  'private_limited': 'Private limited company',
  'public_limited': 'Public limited company',
};

/// The verification form (seller_applications).
class SellerApplication {
  final String status;
  final String ownerName;
  final String contactEmail;
  final String contactPhone;
  final String? businessType;
  final String legalName;
  final String? pan;
  final String? gstin;
  final String pickupLine1;
  final String pickupLine2;
  final String pickupCity;
  final String pickupState;
  final String? pickupPinCode;
  final String? reviewNote;
  final DateTime? submittedAt;

  const SellerApplication({
    this.status = 'draft',
    this.ownerName = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.businessType,
    this.legalName = '',
    this.pan,
    this.gstin,
    this.pickupLine1 = '',
    this.pickupLine2 = '',
    this.pickupCity = '',
    this.pickupState = '',
    this.pickupPinCode,
    this.reviewNote,
    this.submittedAt,
  });

  factory SellerApplication.fromJson(Map<String, dynamic> json) =>
      SellerApplication(
        status: json['status'] as String,
        ownerName: json['owner_name'] as String? ?? '',
        contactEmail: json['contact_email'] as String? ?? '',
        contactPhone: json['contact_phone'] as String? ?? '',
        businessType: json['business_type'] as String?,
        legalName: json['legal_name'] as String? ?? '',
        pan: json['pan'] as String?,
        gstin: json['gstin'] as String?,
        pickupLine1: json['pickup_line1'] as String? ?? '',
        pickupLine2: json['pickup_line2'] as String? ?? '',
        pickupCity: json['pickup_city'] as String? ?? '',
        pickupState: json['pickup_state'] as String? ?? '',
        pickupPinCode: json['pickup_pin_code'] as String?,
        reviewNote: json['review_note'] as String?,
        submittedAt: _date(json['submitted_at']),
      );

  /// The fields a seller may change (the rest change through functions).
  Map<String, dynamic> toUpdateJson() => {
    'owner_name': ownerName,
    'contact_email': contactEmail,
    'contact_phone': contactPhone,
    'business_type': businessType,
    'legal_name': legalName,
    'pan': pan,
    'gstin': gstin,
    'pickup_line1': pickupLine1,
    'pickup_line2': pickupLine2,
    'pickup_city': pickupCity,
    'pickup_state': pickupState,
    'pickup_pin_code': pickupPinCode,
  };

  bool get isEditable => status == 'draft' || status == 'needs_info';
}

class BankAccount {
  final String accountHolder;
  final String last4;
  final String ifsc;

  /// unverified | verified | failed
  final String status;

  const BankAccount({
    required this.accountHolder,
    required this.last4,
    required this.ifsc,
    required this.status,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
    accountHolder: json['account_holder'] as String,
    last4: json['last4'] as String,
    ifsc: json['ifsc'] as String,
    status: json['status'] as String,
  );
}

const documentKinds = {
  'pan_card': 'PAN card',
  'gst_certificate': 'GST registration certificate',
  'cancelled_cheque': 'Cancelled cheque',
  'address_proof': 'Address proof',
  'brand_authorisation': 'Brand authorisation',
  'other': 'Other document',
};

class SellerDocument {
  final String id;
  final String kind;
  final String storagePath;
  final String fileName;
  final DateTime createdAt;

  const SellerDocument({
    required this.id,
    required this.kind,
    required this.storagePath,
    required this.fileName,
    required this.createdAt,
  });

  factory SellerDocument.fromJson(Map<String, dynamic> json) => SellerDocument(
    id: json['id'] as String,
    kind: json['kind'] as String,
    storagePath: json['storage_path'] as String,
    fileName: json['file_name'] as String? ?? '',
    createdAt: _date(json['created_at'])!,
  );
}

class ApplicationEvent {
  final String? fromStatus;
  final String toStatus;
  final String actorRole;
  final String? note;
  final DateTime createdAt;

  const ApplicationEvent({
    this.fromStatus,
    required this.toStatus,
    required this.actorRole,
    this.note,
    required this.createdAt,
  });

  factory ApplicationEvent.fromJson(Map<String, dynamic> json) =>
      ApplicationEvent(
        fromStatus: json['from_status'] as String?,
        toStatus: json['to_status'] as String,
        actorRole: json['actor_role'] as String,
        note: json['note'] as String?,
        createdAt: _date(json['created_at'])!,
      );
}

/// The brand's public storefront (sellers).
class Storefront {
  final String name;
  final String tagline;
  final String story;
  final String? logoUrl;
  final String? bannerUrl;
  final String city;
  final int dispatchDays;
  final int returnWindowDays;
  final String? instagramUrl;
  final String? websiteUrl;
  final String? supportEmail;
  final String returnPolicy;
  final String shippingPolicy;

  const Storefront({
    required this.name,
    this.tagline = '',
    this.story = '',
    this.logoUrl,
    this.bannerUrl,
    this.city = '',
    this.dispatchDays = 2,
    this.returnWindowDays = 7,
    this.instagramUrl,
    this.websiteUrl,
    this.supportEmail,
    this.returnPolicy = '',
    this.shippingPolicy = '',
  });

  factory Storefront.fromJson(Map<String, dynamic> json) => Storefront(
    name: json['name'] as String,
    tagline: json['tagline'] as String? ?? '',
    story: json['story'] as String? ?? '',
    logoUrl: json['logo_url'] as String?,
    bannerUrl: json['banner_url'] as String?,
    city: json['city'] as String? ?? '',
    dispatchDays: _int(json['dispatch_days']),
    returnWindowDays: _int(json['return_window_days']),
    instagramUrl: json['instagram_url'] as String?,
    websiteUrl: json['website_url'] as String?,
    supportEmail: json['support_email'] as String?,
    returnPolicy: json['return_policy'] as String? ?? '',
    shippingPolicy: json['shipping_policy'] as String? ?? '',
  );

  Map<String, dynamic> toUpdateJson() => {
    'name': name,
    'tagline': tagline,
    'story': story,
    'logo_url': logoUrl,
    'banner_url': bannerUrl,
    'city': city,
    'dispatch_days': dispatchDays,
    'return_window_days': returnWindowDays,
    'instagram_url': instagramUrl,
    'website_url': websiteUrl,
    'support_email': supportEmail,
    'return_policy': returnPolicy,
    'shipping_policy': shippingPolicy,
  };

  Storefront copyWith({String? logoUrl, String? bannerUrl}) => Storefront(
    name: name,
    tagline: tagline,
    story: story,
    logoUrl: logoUrl ?? this.logoUrl,
    bannerUrl: bannerUrl ?? this.bannerUrl,
    city: city,
    dispatchDays: dispatchDays,
    returnWindowDays: returnWindowDays,
    instagramUrl: instagramUrl,
    websiteUrl: websiteUrl,
    supportEmail: supportEmail,
    returnPolicy: returnPolicy,
    shippingPolicy: shippingPolicy,
  );
}

const productStatuses = {
  'draft': 'Draft',
  'pending_review': 'In review',
  'live': 'Live',
  'rejected': 'Changes needed',
  'archived': 'Unpublished',
};

class SellerVariant {
  final String id;
  final String productId;
  final String sku;
  final String title;
  final String size;
  final String colorName;
  final String colorHex;
  final int price;
  final int? compareAtPrice;
  final int stock;
  final bool isActive;
  final int lowStockThreshold;
  final bool isLowStock;

  const SellerVariant({
    required this.id,
    required this.productId,
    required this.sku,
    required this.title,
    required this.size,
    this.colorName = '',
    this.colorHex = '',
    required this.price,
    this.compareAtPrice,
    required this.stock,
    this.isActive = true,
    this.lowStockThreshold = 3,
    this.isLowStock = false,
  });

  factory SellerVariant.fromJson(Map<String, dynamic> json) => SellerVariant(
    id: json['id'] as String,
    productId: json['product_id'] as String,
    sku: json['sku'] as String,
    title: json['title'] as String,
    size: json['size'] as String,
    colorName: json['color_name'] as String? ?? '',
    colorHex: json['color_hex'] as String? ?? '',
    price: _int(json['price']),
    compareAtPrice: (json['compare_at_price'] as num?)?.toInt(),
    stock: _int(json['stock']),
    isActive: json['is_active'] as bool? ?? true,
    lowStockThreshold: _int(json['low_stock_threshold']),
    isLowStock: json['is_low_stock'] as bool? ?? false,
  );
}

/// What the seller types in for one size.
class VariantDraft {
  final String sku;
  final String size;
  final String colorName;
  final String colorHex;
  final int price;
  final int? compareAtPrice;
  final int stock;
  final int lowStockThreshold;
  final bool isActive;

  const VariantDraft({
    required this.sku,
    required this.size,
    this.colorName = '',
    this.colorHex = '',
    required this.price,
    this.compareAtPrice,
    this.stock = 0,
    this.lowStockThreshold = 3,
    this.isActive = true,
  });

  String get title => colorName.isEmpty ? size : '$colorName / $size';

  Map<String, dynamic> toJson({bool includeStock = true}) => {
    'sku': sku,
    'title': title,
    'size': size,
    'color_name': colorName,
    'color_hex': colorHex,
    'price': price,
    'compare_at_price': compareAtPrice,
    'low_stock_threshold': lowStockThreshold,
    'is_active': isActive,
    if (includeStock) 'stock': stock,
  };
}

class SellerProduct {
  final String id;
  final String handle;
  final String title;
  final String description;
  final String category;
  final List<String> categoryHandles;
  final List<String> tags;
  final List<String> images;

  /// draft | pending_review | live | rejected | archived
  final String status;
  final String? rejectionReason;
  final bool tryOnRequested;
  final bool isTryOnEligible;
  final String? hsnCode;
  final int minPrice;
  final DateTime? approvedAt;
  final DateTime updatedAt;
  final List<SellerVariant> variants;

  const SellerProduct({
    required this.id,
    required this.handle,
    required this.title,
    this.description = '',
    this.category = '',
    this.categoryHandles = const [],
    this.tags = const [],
    this.images = const [],
    required this.status,
    this.rejectionReason,
    this.tryOnRequested = false,
    this.isTryOnEligible = false,
    this.hsnCode,
    this.minPrice = 0,
    this.approvedAt,
    required this.updatedAt,
    this.variants = const [],
  });

  factory SellerProduct.fromJson(Map<String, dynamic> json) => SellerProduct(
    id: json['id'] as String,
    handle: json['handle'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? '',
    categoryHandles: _strings(json['category_handles']),
    tags: _strings(json['tags']),
    images: _strings(json['images']),
    status: json['status'] as String,
    rejectionReason: json['rejection_reason'] as String?,
    tryOnRequested: json['tryon_requested'] as bool? ?? false,
    isTryOnEligible: json['is_tryon_eligible'] as bool? ?? false,
    hsnCode: json['hsn_code'] as String?,
    minPrice: _int(json['min_price']),
    approvedAt: _date(json['approved_at']),
    updatedAt: _date(json['updated_at']) ?? DateTime.now(),
    variants:
        ((json['variants'] as List?) ?? const [])
            .map((v) => SellerVariant.fromJson((v as Map).cast()))
            .toList()
          ..sort((a, b) => a.sku.compareTo(b.sku)),
  );

  int get totalStock =>
      variants.where((v) => v.isActive).fold(0, (sum, v) => sum + v.stock);
  bool get canEdit => status != 'pending_review';
  bool get canSubmit => status == 'draft' || status == 'rejected';
  bool get canDelete =>
      approvedAt == null && (status == 'draft' || status == 'rejected');
}

/// What the seller types in for a listing.
class ProductDraft {
  final String title;
  final String description;
  final String category;
  final List<String> categoryHandles;
  final List<String> tags;
  final List<String> images;
  final bool tryOnRequested;
  final String? hsnCode;

  const ProductDraft({
    required this.title,
    this.description = '',
    this.category = '',
    this.categoryHandles = const [],
    this.tags = const [],
    this.images = const [],
    this.tryOnRequested = false,
    this.hsnCode,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category': category,
    'category_handles': categoryHandles,
    'tags': tags,
    'images': images,
    'tryon_requested': tryOnRequested,
    'hsn_code': hsnCode,
  };
}

class StockMovement {
  final int id;
  final String sku;
  final String variantTitle;
  final String productTitle;
  final int delta;
  final String reason;
  final String? note;
  final DateTime createdAt;

  const StockMovement({
    required this.id,
    required this.sku,
    required this.variantTitle,
    required this.productTitle,
    required this.delta,
    required this.reason,
    this.note,
    required this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    final variant = (json['variant'] as Map?)?.cast<String, dynamic>() ?? {};
    final product = (variant['product'] as Map?)?.cast<String, dynamic>() ?? {};
    return StockMovement(
      id: _int(json['id']),
      sku: variant['sku'] as String? ?? '',
      variantTitle: variant['title'] as String? ?? '',
      productTitle: product['title'] as String? ?? '',
      delta: _int(json['delta']),
      reason: json['reason'] as String,
      note: json['note'] as String?,
      createdAt: _date(json['created_at'])!,
    );
  }
}

const stockReasons = {
  'seed': 'Opening stock',
  'restock': 'Restock',
  'adjustment': 'Adjustment',
  'order_reserve': 'Ordered',
  'order_release': 'Order cancelled',
  'bulk_import': 'Bulk import',
};

const orderStatuses = {
  'pending_payment': 'Awaiting payment',
  'placed': 'New',
  'confirmed': 'Accepted',
  'packed': 'Packed',
  'shipped': 'Shipped',
  'out_for_delivery': 'Out for delivery',
  'delivered': 'Delivered',
  'cancelled': 'Cancelled',
  'returned': 'Returned',
};

class SellerOrderItem {
  final String title;
  final String variantTitle;
  final String size;
  final String colorName;
  final String? imageUrl;
  final int unitPrice;
  final int quantity;

  const SellerOrderItem({
    required this.title,
    required this.variantTitle,
    required this.size,
    this.colorName = '',
    this.imageUrl,
    required this.unitPrice,
    required this.quantity,
  });

  factory SellerOrderItem.fromJson(Map<String, dynamic> json) =>
      SellerOrderItem(
        title: json['title'] as String,
        variantTitle: json['variant_title'] as String? ?? '',
        size: json['size'] as String? ?? '',
        colorName: json['color_name'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
        unitPrice: _int(json['unit_price']),
        quantity: _int(json['quantity']),
      );

  int get lineTotal => unitPrice * quantity;
}

class Shipment {
  final String? carrier;
  final String? trackingNumber;
  final String? trackingUrl;
  final String status;

  const Shipment({
    this.carrier,
    this.trackingNumber,
    this.trackingUrl,
    required this.status,
  });

  factory Shipment.fromJson(Map<String, dynamic> json) => Shipment(
    carrier: json['carrier'] as String?,
    trackingNumber: json['tracking_number'] as String?,
    trackingUrl: json['tracking_url'] as String?,
    status: json['status'] as String,
  );
}

/// One brand's part of a shopper's order (seller_orders).
class SellerOrder {
  final String id;
  final String orderId;
  final String reference;
  final String status;
  final int subtotal;
  final int total;
  final DateTime createdAt;
  final DateTime? dispatchBy;
  final DateTime? deliveredAt;
  final String? cancelReason;
  final String? cancelledBy;
  final String? invoiceNumber;
  final List<SellerOrderItem> items;
  final Shipment? shipment;

  const SellerOrder({
    required this.id,
    required this.orderId,
    required this.reference,
    required this.status,
    required this.subtotal,
    required this.total,
    required this.createdAt,
    this.dispatchBy,
    this.deliveredAt,
    this.cancelReason,
    this.cancelledBy,
    this.invoiceNumber,
    this.items = const [],
    this.shipment,
  });

  factory SellerOrder.fromJson(Map<String, dynamic> json) {
    final shipments = (json['shipments'] as List?) ?? const [];
    return SellerOrder(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      reference: json['reference'] as String,
      status: json['status'] as String,
      subtotal: _int(json['subtotal']),
      total: _int(json['total']),
      createdAt: _date(json['created_at'])!,
      dispatchBy: _date(json['dispatch_by']),
      deliveredAt: _date(json['delivered_at']),
      cancelReason: json['cancel_reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      items: ((json['items'] as List?) ?? const [])
          .map((i) => SellerOrderItem.fromJson((i as Map).cast()))
          .toList(),
      shipment: shipments.isEmpty
          ? null
          : Shipment.fromJson((shipments.first as Map).cast()),
    );
  }

  int get units => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isOpen =>
      status == 'placed' || status == 'confirmed' || status == 'packed';
  bool isLate(DateTime now) =>
      isOpen && dispatchBy != null && dispatchBy!.isBefore(now);
  bool get canAccept => status == 'placed';
  bool get canPack => status == 'placed' || status == 'confirmed';
  bool get canShip => status == 'packed';
  bool get canCancel => status == 'placed' || status == 'confirmed';
  bool get canDeliver => status == 'shipped' || status == 'out_for_delivery';
  bool get hasInvoice => invoiceNumber != null;
}

const settlementStatuses = {
  'pending': 'In return window',
  'eligible': 'Ready for payout',
  'in_payout': 'In a payout',
  'paid': 'Paid',
  'reversed': 'Reversed (returned)',
};

class Settlement {
  final String id;
  final String reference;
  final int gross;
  final int commission;
  final int shippingFee;
  final int collectionFee;
  final int gstOnFees;
  final int net;
  final String status;
  final DateTime deliveredAt;
  final DateTime eligibleAt;
  final String? payoutId;

  const Settlement({
    required this.id,
    required this.reference,
    required this.gross,
    required this.commission,
    required this.shippingFee,
    required this.collectionFee,
    required this.gstOnFees,
    required this.net,
    required this.status,
    required this.deliveredAt,
    required this.eligibleAt,
    this.payoutId,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
    id: json['id'] as String,
    reference: json['reference'] as String,
    gross: _int(json['gross']),
    commission: _int(json['commission']),
    shippingFee: _int(json['shipping_fee']),
    collectionFee: _int(json['collection_fee']),
    gstOnFees: _int(json['gst_on_fees']),
    net: _int(json['net']),
    status: json['status'] as String,
    deliveredAt: _date(json['delivered_at'])!,
    eligibleAt: _date(json['eligible_at'])!,
    payoutId: json['payout_id'] as String?,
  );
}

const payoutStatuses = {
  'pending': 'Scheduled',
  'processing': 'Processing',
  'paid': 'Paid',
  'failed': 'Failed — retrying',
};

class Payout {
  final String id;
  final int amount;
  final String status;
  final String? utr;
  final String accountLast4;
  final int settlementCount;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? lastError;

  const Payout({
    required this.id,
    required this.amount,
    required this.status,
    this.utr,
    required this.accountLast4,
    this.settlementCount = 0,
    required this.createdAt,
    this.processedAt,
    this.lastError,
  });

  factory Payout.fromJson(Map<String, dynamic> json) => Payout(
    id: json['id'] as String,
    amount: _int(json['amount']),
    status: json['status'] as String,
    utr: json['utr'] as String?,
    accountLast4: json['account_last4'] as String,
    settlementCount: _int(json['settlement_count']),
    createdAt: _date(json['created_at'])!,
    processedAt: _date(json['processed_at']),
    lastError: json['last_error'] as String?,
  );
}

class Adjustment {
  final int amount;
  final String reason;
  final DateTime createdAt;
  final String? payoutId;

  const Adjustment({
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.payoutId,
  });

  factory Adjustment.fromJson(Map<String, dynamic> json) => Adjustment(
    amount: _int(json['amount']),
    reason: json['reason'] as String,
    createdAt: _date(json['created_at'])!,
    payoutId: json['payout_id'] as String?,
  );
}

/// seller_dashboard.
class SellerDashboard {
  final int ordersToday;
  final int newOrders;
  final int toPack;
  final int toShip;
  final int inTransit;
  final int late;
  final int sales30dOrders;
  final int sales30dUnits;
  final int sales30dGmv;
  final int sales30dAov;
  final Map<String, int> products;
  final int lowStock;
  final int moneyPending;
  final int moneyEligible;
  final int? lastPayoutAmount;
  final String? lastPayoutStatus;
  final int? performanceScore;
  final double cancellationRate;
  final double lateDispatchRate;

  const SellerDashboard({
    this.ordersToday = 0,
    this.newOrders = 0,
    this.toPack = 0,
    this.toShip = 0,
    this.inTransit = 0,
    this.late = 0,
    this.sales30dOrders = 0,
    this.sales30dUnits = 0,
    this.sales30dGmv = 0,
    this.sales30dAov = 0,
    this.products = const {},
    this.lowStock = 0,
    this.moneyPending = 0,
    this.moneyEligible = 0,
    this.lastPayoutAmount,
    this.lastPayoutStatus,
    this.performanceScore,
    this.cancellationRate = 0,
    this.lateDispatchRate = 0,
  });

  factory SellerDashboard.fromJson(Map<String, dynamic> json) {
    final orders = (json['orders'] as Map?)?.cast<String, dynamic>() ?? {};
    final sales = (json['sales_30d'] as Map?)?.cast<String, dynamic>() ?? {};
    final money = (json['money'] as Map?)?.cast<String, dynamic>() ?? {};
    final last = (money['last_payout'] as Map?)?.cast<String, dynamic>();
    final perf = (json['performance'] as Map?)?.cast<String, dynamic>() ?? {};
    return SellerDashboard(
      ordersToday: _int(orders['today']),
      newOrders: _int(orders['new']),
      toPack: _int(orders['to_pack']),
      toShip: _int(orders['to_ship']),
      inTransit: _int(orders['in_transit']),
      late: _int(orders['late']),
      sales30dOrders: _int(sales['orders']),
      sales30dUnits: _int(sales['units']),
      sales30dGmv: _int(sales['gmv']),
      sales30dAov: _int(sales['aov']),
      products: ((json['products'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k as String, _int(v)),
      ),
      lowStock: _int(json['low_stock']),
      moneyPending: _int(money['pending']),
      moneyEligible: _int(money['eligible']),
      lastPayoutAmount: (last?['amount'] as num?)?.toInt(),
      lastPayoutStatus: last?['status'] as String?,
      performanceScore: (perf['score'] as num?)?.toInt(),
      cancellationRate:
          (perf['seller_cancellation_rate'] as num?)?.toDouble() ?? 0,
      lateDispatchRate: (perf['late_dispatch_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SalesDay {
  final DateTime day;
  final int orders;
  final int units;
  final int gmv;

  const SalesDay({
    required this.day,
    required this.orders,
    required this.units,
    required this.gmv,
  });

  factory SalesDay.fromJson(Map<String, dynamic> json) => SalesDay(
    day: DateTime.parse(json['day'] as String),
    orders: _int(json['orders']),
    units: _int(json['units']),
    gmv: _int(json['gmv']),
  );
}

class TopProduct {
  final String productId;
  final String title;
  final int units;
  final int gmv;

  const TopProduct({
    required this.productId,
    required this.title,
    required this.units,
    required this.gmv,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
    productId: json['product_id'] as String,
    title: json['title'] as String,
    units: _int(json['units']),
    gmv: _int(json['gmv']),
  );
}

class TryOnInsight {
  final String productId;
  final String title;
  final int tryOns;
  final int shoppers;
  final int buyers;

  const TryOnInsight({
    required this.productId,
    required this.title,
    required this.tryOns,
    required this.shoppers,
    required this.buyers,
  });

  factory TryOnInsight.fromJson(Map<String, dynamic> json) => TryOnInsight(
    productId: json['product_id'] as String,
    title: json['title'] as String,
    tryOns: _int(json['tryons']),
    shoppers: _int(json['shoppers']),
    buyers: _int(json['buyers']),
  );

  /// Share of shoppers who tried it on and then bought it.
  double get conversion => shoppers == 0 ? 0 : buyers / shoppers;
}

class SellerCollection {
  final String id;
  final String title;
  final String description;
  final List<String> productIds;
  final int position;
  final bool isVisible;

  const SellerCollection({
    required this.id,
    required this.title,
    this.description = '',
    this.productIds = const [],
    this.position = 0,
    this.isVisible = true,
  });

  factory SellerCollection.fromJson(Map<String, dynamic> json) =>
      SellerCollection(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        productIds: _strings(json['product_ids']),
        position: _int(json['position']),
        isVisible: json['is_visible'] as bool? ?? true,
      );
}
