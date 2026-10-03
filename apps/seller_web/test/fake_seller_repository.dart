import 'dart:async';
import 'dart:typed_data';

import 'package:clothsy_seller/data/models.dart';
import 'package:clothsy_seller/data/seller_repository.dart';

/// An in-memory Clothsy backend for widget tests, following the same rules
/// as the database functions for the parts the panel uses.
class FakeSellerRepository implements SellerRepository {
  FakeSellerRepository({
    this.signedIn = false,
    List<SellerContext>? sellers,
    List<SellerOrder>? orders,
    SellerDashboard? dashboard,
  }) : sellers = sellers ?? [],
       orderList = orders ?? [],
       dashboardData = dashboard ?? const SellerDashboard();

  bool signedIn;
  final List<SellerContext> sellers;
  final List<SellerOrder> orderList;
  SellerDashboard dashboardData;
  SellerApplication applicationData = const SellerApplication();
  BankAccount? bank;
  final List<SellerDocument> docs = [];
  final List<String> calls = [];
  final _auth = StreamController<bool>.broadcast();

  static SellerContext store({
    String status = 'approved',
    String applicationStatus = 'approved',
    List<String> missing = const [],
    String? reviewNote,
  }) => SellerContext(
    sellerId: 's1',
    handle: 'kiet-threads',
    name: 'Kiet Threads',
    status: status,
    role: 'owner',
    applicationStatus: applicationStatus,
    missing: missing,
    reviewNote: reviewNote,
  );

  static SellerOrder order({
    String id = 'so1',
    String status = 'placed',
    String? invoiceNumber,
    DateTime? dispatchBy,
  }) => SellerOrder(
    id: id,
    orderId: 'o1',
    reference: 'CLY-10000001-A',
    status: status,
    subtotal: 189900,
    total: 204900,
    createdAt: DateTime(2026, 10, 2, 10),
    dispatchBy: dispatchBy ?? DateTime.now().add(const Duration(days: 2)),
    invoiceNumber: invoiceNumber,
    items: const [
      SellerOrderItem(
        title: 'Linen Shirt',
        variantTitle: 'Ivory / M',
        size: 'M',
        unitPrice: 189900,
        quantity: 1,
      ),
    ],
  );

  static Map<String, dynamic> invoiceFor(SellerOrder o) => {
    'invoice_number': o.invoiceNumber ?? 'KIET/2627/00001',
    'invoice_date': '2026-10-02',
    'order_number': 'CLY-10000001',
    'reference': o.reference,
    'payment_method': 'cod',
    'cod_amount': o.total,
    'seller': {
      'name': 'Kiet Threads',
      'legal_name': 'Kiet Threads Pvt Ltd',
      'gstin': '07ABCPK1234F1Z5',
      'pan': 'ABCPK1234F',
      'line1': '1 Okhla',
      'city': 'New Delhi',
      'state': 'Delhi',
      'pin_code': '110020',
    },
    'buyer': {
      'name': 'Riya',
      'phone': '+919999900001',
      'line1': '1 MG Road',
      'city': 'New Delhi',
      'state': 'Delhi',
      'pin_code': '110001',
    },
    'place_of_supply': 'Delhi',
    'intra_state': true,
    'lines': [
      {
        'title': 'Linen Shirt',
        'variant': 'Ivory / M',
        'sku': 'KLS-M',
        'hsn_code': '6206',
        'quantity': 1,
        'unit_price': 189900,
        'total': 189900,
        'gst_rate_bps': 500,
        'taxable_value': 180857,
        'cgst': 4521,
        'sgst': 4522,
        'igst': 0,
      },
    ],
    'totals': {
      'taxable_value': 180857,
      'cgst': 4521,
      'sgst': 4522,
      'igst': 0,
      'total': 189900,
    },
    'shipment': null,
  };

  void _set(String id, SellerOrder Function(SellerOrder) change) {
    final i = orderList.indexWhere((o) => o.id == id);
    orderList[i] = change(orderList[i]);
  }

  SellerOrder _copy(
    SellerOrder o, {
    String? status,
    String? invoiceNumber,
    String? cancelReason,
    Shipment? shipment,
  }) => SellerOrder(
    id: o.id,
    orderId: o.orderId,
    reference: o.reference,
    status: status ?? o.status,
    subtotal: o.subtotal,
    total: o.total,
    createdAt: o.createdAt,
    dispatchBy: o.dispatchBy,
    invoiceNumber: invoiceNumber ?? o.invoiceNumber,
    cancelReason: cancelReason ?? o.cancelReason,
    cancelledBy: cancelReason == null ? o.cancelledBy : 'seller',
    items: o.items,
    shipment: shipment ?? o.shipment,
  );

  // Account
  @override
  Stream<bool> get signedInChanges => _auth.stream;
  @override
  bool get isSignedIn => signedIn;
  @override
  String? get userEmail => signedIn ? 'founder@kiet.test' : null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (password != 'right-password') {
      throw const SellerFailure('INVALID_CREDENTIALS');
    }
    signedIn = true;
    _auth.add(true);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    signedIn = true;
    _auth.add(true);
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
    _auth.add(false);
  }

  // Store and verification
  @override
  Future<List<SellerContext>> mySellers() async => List.of(sellers);

  @override
  Future<String> registerSeller(String brandName) async {
    calls.add('register $brandName');
    sellers.add(
      store(
        status: 'pending',
        applicationStatus: 'draft',
        missing: const ['owner_name', 'pan', 'bank_account'],
      ),
    );
    return 's1';
  }

  @override
  Future<SellerApplication> application(String sellerId) async =>
      SellerApplication(
        status: sellers.first.applicationStatus,
        reviewNote: sellers.first.reviewNote,
        ownerName: applicationData.ownerName,
        pan: applicationData.pan,
      );

  @override
  Future<void> saveApplication(String sellerId, SellerApplication a) async {
    calls.add('save application');
    applicationData = a;
  }

  @override
  Future<BankAccount?> bankAccount(String sellerId) async => bank;

  @override
  Future<BankAccount> setBankAccount(
    String sellerId, {
    required String accountHolder,
    required String accountNumber,
    required String ifsc,
  }) async => bank = BankAccount(
    accountHolder: accountHolder,
    last4: accountNumber.substring(accountNumber.length - 4),
    ifsc: ifsc,
    status: 'unverified',
  );

  @override
  Future<List<SellerDocument>> documents(String sellerId) async =>
      List.of(docs);

  @override
  Future<void> uploadDocument(
    String sellerId, {
    required String kind,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    calls.add('upload $kind $fileName');
    docs.add(
      SellerDocument(
        id: 'd${docs.length}',
        kind: kind,
        storagePath: '$sellerId/$fileName',
        fileName: fileName,
        createdAt: DateTime(2026, 10, 2),
      ),
    );
  }

  @override
  Future<void> deleteDocument(SellerDocument document) async =>
      docs.remove(document);

  @override
  Future<void> submitApplication(String sellerId) async {
    final s = sellers.first;
    if (s.missing.isNotEmpty) {
      throw SellerFailure('APPLICATION_INCOMPLETE', {'missing': s.missing});
    }
    calls.add('submit application');
    sellers[0] = store(status: 'pending', applicationStatus: 'submitted');
  }

  @override
  Future<List<ApplicationEvent>> applicationHistory(String sellerId) async => [
    ApplicationEvent(
      toStatus: 'draft',
      actorRole: 'seller',
      createdAt: DateTime(2026, 10, 2),
    ),
  ];

  // Orders
  @override
  Future<List<SellerOrder>> orders(String sellerId) async => List.of(orderList);

  @override
  Future<void> acceptOrder(String sellerOrderId) async {
    calls.add('accept $sellerOrderId');
    _set(sellerOrderId, (o) => _copy(o, status: 'confirmed'));
  }

  @override
  Future<String> packOrder(String sellerOrderId) async {
    calls.add('pack $sellerOrderId');
    _set(
      sellerOrderId,
      (o) => _copy(o, status: 'packed', invoiceNumber: 'KIET/2627/00001'),
    );
    return 'KIET/2627/00001';
  }

  @override
  Future<void> shipOrder(
    String sellerOrderId, {
    required String carrier,
    required String trackingNumber,
    String? trackingUrl,
  }) async {
    calls.add('ship $sellerOrderId $carrier $trackingNumber');
    _set(
      sellerOrderId,
      (o) => _copy(
        o,
        status: 'shipped',
        shipment: Shipment(
          carrier: carrier,
          trackingNumber: trackingNumber,
          status: 'in_transit',
        ),
      ),
    );
  }

  @override
  Future<void> markDelivered(String sellerOrderId) async {
    calls.add('deliver $sellerOrderId');
    _set(sellerOrderId, (o) => _copy(o, status: 'delivered'));
  }

  @override
  Future<void> cancelOrder(String sellerOrderId, String reason) async {
    calls.add('cancel $sellerOrderId $reason');
    _set(
      sellerOrderId,
      (o) => _copy(o, status: 'cancelled', cancelReason: reason),
    );
  }

  @override
  Future<Map<String, dynamic>> invoice(String sellerOrderId) async =>
      invoiceFor(orderList.firstWhere((o) => o.id == sellerOrderId));

  // Insights used by the dashboard
  @override
  Future<SellerDashboard> dashboard(String sellerId) async => dashboardData;

  @override
  Future<List<SalesDay>> salesDaily(String sellerId, {int days = 30}) async => [
    for (var i = days - 1; i >= 0; i--)
      SalesDay(
        day: DateTime(2026, 10, 2).subtract(Duration(days: i)),
        orders: i % 3,
        units: i % 3,
        gmv: (i % 3) * 99900,
      ),
  ];

  // Products
  final List<SellerProduct> productList = [];

  static SellerProduct sampleProduct({
    String id = 'p1',
    String title = 'Linen Shirt',
    String status = 'draft',
    String description = '',
    List<String> images = const [],
    List<SellerVariant> variants = const [],
    String? rejectionReason,
    DateTime? approvedAt,
  }) => SellerProduct(
    id: id,
    handle: 'linen-shirt-abc123',
    title: title,
    description: description,
    category: 'Tops',
    categoryHandles: const ['women', 'tops'],
    images: images,
    status: status,
    rejectionReason: rejectionReason,
    approvedAt: approvedAt,
    updatedAt: DateTime(2026, 10, 4, 10, _productClock++),
    variants: variants,
    minPrice: variants.isEmpty ? 0 : variants.first.price,
  );
  static int _productClock = 0;

  void _setProduct(
    String id, {
    String? status,
    ProductDraft? draft,
    List<SellerVariant>? variants,
  }) {
    final i = productList.indexWhere((p) => p.id == id);
    final p = productList[i];
    productList[i] = sampleProduct(
      id: p.id,
      title: draft?.title ?? p.title,
      description: draft?.description ?? p.description,
      images: draft?.images ?? p.images,
      status: status ?? p.status,
      rejectionReason: p.rejectionReason,
      approvedAt: status == 'live' ? DateTime(2026, 10, 4) : p.approvedAt,
      variants: variants ?? p.variants,
    );
  }

  @override
  Future<List<SellerProduct>> products(String sellerId) async =>
      List.of(productList);

  @override
  Future<SellerProduct> product(String productId) async =>
      productList.firstWhere((p) => p.id == productId);

  @override
  Future<String> createProduct(String sellerId, ProductDraft draft) async {
    calls.add('create ${draft.title}');
    final id = 'p${productList.length + 1}';
    productList.add(sampleProduct(id: id, title: draft.title));
    _setProduct(id, draft: draft);
    return id;
  }

  @override
  Future<void> updateProduct(String productId, ProductDraft draft) async {
    calls.add('update ${draft.title}');
    _setProduct(productId, draft: draft);
  }

  @override
  Future<void> deleteProduct(String productId) async {
    calls.add('delete $productId');
    productList.removeWhere((p) => p.id == productId);
  }

  @override
  Future<void> addVariant(String productId, VariantDraft draft) async {
    calls.add('add variant ${draft.sku} ${draft.price}');
    final p = productList.firstWhere((p) => p.id == productId);
    _setProduct(
      productId,
      variants: [
        ...p.variants,
        SellerVariant(
          id: 'v${p.variants.length + 1}',
          productId: productId,
          sku: draft.sku,
          title: draft.title,
          size: draft.size,
          price: draft.price,
          compareAtPrice: draft.compareAtPrice,
          stock: draft.stock,
        ),
      ],
    );
  }

  @override
  Future<void> submitProduct(String productId) async {
    final p = productList.firstWhere((p) => p.id == productId);
    final missing = [
      if (p.description.length < 20) 'description',
      if (p.images.isEmpty) 'images',
      if (p.variants.isEmpty) 'variants',
    ];
    if (missing.isNotEmpty) {
      throw SellerFailure('PRODUCT_INCOMPLETE', {'missing': missing});
    }
    calls.add('submit $productId');
    _setProduct(productId, status: 'pending_review');
  }

  @override
  Future<void> setListed(String productId, bool listed) async {
    calls.add('listed $productId $listed');
    _setProduct(productId, status: listed ? 'live' : 'archived');
  }

  @override
  Future<String> uploadImage(
    String sellerId, {
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    calls.add('upload image $fileName');
    return 'https://example.com/$fileName';
  }

  // Not used by the screens built so far.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
