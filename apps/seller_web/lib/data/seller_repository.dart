import 'dart:typed_data';

import 'models.dart';

/// Everything the Seller Panel reads and changes. Screens only talk to this
/// interface; [SupabaseSellerRepository] is the real one and tests use a
/// fake.
abstract class SellerRepository {
  // Account
  Stream<bool> get signedInChanges;
  bool get isSignedIn;
  String? get userEmail;
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  });
  Future<void> signOut();

  // Store and verification
  Future<List<SellerContext>> mySellers();
  Future<String> registerSeller(String brandName);
  Future<SellerApplication> application(String sellerId);
  Future<void> saveApplication(String sellerId, SellerApplication application);
  Future<BankAccount?> bankAccount(String sellerId);
  Future<BankAccount> setBankAccount(
    String sellerId, {
    required String accountHolder,
    required String accountNumber,
    required String ifsc,
  });
  Future<List<SellerDocument>> documents(String sellerId);
  Future<void> uploadDocument(
    String sellerId, {
    required String kind,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  });
  Future<void> deleteDocument(SellerDocument document);
  Future<void> submitApplication(String sellerId);
  Future<List<ApplicationEvent>> applicationHistory(String sellerId);

  // Storefront
  Future<Storefront> storefront(String sellerId);
  Future<void> saveStorefront(String sellerId, Storefront storefront);

  /// Uploads a public catalogue image for the brand; returns its URL.
  Future<String> uploadImage(
    String sellerId, {
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  });
  Future<List<SellerCollection>> collections(String sellerId);
  Future<void> saveCollection(
    String sellerId, {
    String? id,
    required String title,
    required String description,
    required List<String> productIds,
    required bool isVisible,
  });
  Future<void> deleteCollection(String id);

  // Products and stock
  Future<List<SellerProduct>> products(String sellerId);
  Future<SellerProduct> product(String productId);
  Future<String> createProduct(String sellerId, ProductDraft draft);
  Future<void> updateProduct(String productId, ProductDraft draft);
  Future<void> deleteProduct(String productId);
  Future<void> addVariant(String productId, VariantDraft draft);
  Future<void> updateVariant(String variantId, VariantDraft draft);
  Future<void> deleteVariant(String variantId);
  Future<void> submitProduct(String productId);
  Future<void> setListed(String productId, bool listed);
  Future<int> adjustStock(String variantId, int delta, {String? note});
  Future<({int updated, int unchanged})> bulkSetStock(
    String sellerId,
    List<({String sku, int stock})> rows,
  );
  Future<List<StockMovement>> stockHistory(String sellerId, {int limit = 100});

  // Orders
  Future<List<SellerOrder>> orders(String sellerId);
  Future<void> acceptOrder(String sellerOrderId);
  Future<String> packOrder(String sellerOrderId);
  Future<void> shipOrder(
    String sellerOrderId, {
    required String carrier,
    required String trackingNumber,
    String? trackingUrl,
  });
  Future<void> markDelivered(String sellerOrderId);
  Future<void> cancelOrder(String sellerOrderId, String reason);
  Future<Map<String, dynamic>> invoice(String sellerOrderId);

  // Money and insights
  Future<List<Settlement>> settlements(String sellerId);
  Future<List<Payout>> payouts(String sellerId);
  Future<List<Adjustment>> adjustments(String sellerId);
  Future<SellerDashboard> dashboard(String sellerId);
  Future<List<SalesDay>> salesDaily(String sellerId, {int days = 30});
  Future<List<TopProduct>> topProducts(String sellerId, {int days = 30});
  Future<List<TryOnInsight>> tryOnInsights(String sellerId, {int days = 30});
}

/// A failure the panel can explain: the server's code and details.
class SellerFailure implements Exception {
  final String code;
  final Map<String, dynamic> details;

  const SellerFailure(this.code, [this.details = const {}]);

  /// Items listed in `details.missing` (application or listing).
  List<String> get missing =>
      ((details['missing'] as List?) ?? const []).cast<String>();

  String get message => sellerMessage(code, details);

  @override
  String toString() => 'SellerFailure($code)';
}

/// What to tell the seller for a server error code.
String sellerMessage(String code, [Map<String, dynamic> details = const {}]) {
  switch (code) {
    case 'INVALID_CREDENTIALS':
      return 'That email and password do not match.';
    case 'EMAIL_TAKEN':
      return 'An account with this email already exists. Sign in instead.';
    case 'WEAK_PASSWORD':
      return 'Choose a password of at least 8 characters.';
    case 'ALREADY_REGISTERED':
      return 'You already own a store on Clothsy.';
    case 'INVALID_NAME':
      return 'Brand names are 2 to 60 characters.';
    case 'APPLICATION_INCOMPLETE':
      return 'A few details are still missing — see the list below.';
    case 'APPLICATION_LOCKED':
      return 'Your application is with Clothsy, so it cannot be changed now.';
    case 'INVALID_BANK_DETAILS':
      return 'Check the account number (9–18 digits) and IFSC (e.g. HDFC0001234).';
    case 'PRODUCT_INCOMPLETE':
      return 'This listing needs a few more details before review.';
    case 'SELLER_NOT_APPROVED':
      return 'Listings can be sent for review once Clothsy approves your store.';
    case 'NOT_SUBMITTABLE':
      return 'This listing is already in review or live.';
    case 'INSUFFICIENT_STOCK':
      return 'There is not that much stock to remove.';
    case 'INVALID_IMPORT':
      return 'Some rows could not be imported — nothing was changed.';
    case 'DUPLICATE_SKU':
      return 'That SKU is already used for another size.';
    case 'INVALID_TRANSITION':
      return 'This order has moved on — refresh to see where it is.';
    case 'NOT_CANCELLABLE':
      return 'Packed orders cannot be cancelled here. Contact Clothsy support.';
    case 'REASON_REQUIRED':
      return 'Tell the shopper why you are cancelling.';
    case 'TRACKING_REQUIRED':
      return 'Enter the courier and its tracking (AWB) number.';
    case 'INVALID_TRACKING_URL':
      return 'Tracking links start with https://';
    case 'NOT_INVOICED':
      return 'The invoice is created when the order is packed.';
    case 'CONFIRM_EMAIL':
      return 'Check your inbox and confirm your email, then sign in.';
    case 'NOT_ALLOWED':
      return 'Your role in this store cannot do that. Ask the store owner.';
    case 'NOT_DELETABLE':
      return 'This was live once, so it can be unpublished but not deleted.';
    case 'UPLOAD_FAILED':
      return 'The upload failed. Use a JPG, PNG or PDF under 10 MB.';
    case 'NETWORK_ERROR':
      return "Can't reach Clothsy right now. Check your connection.";
    default:
      return 'Something went wrong ($code). Please try again.';
  }
}

/// Field names in `missing` lists, as the seller sees them.
const missingLabels = {
  'owner_name': "Owner's name",
  'contact_email': 'Contact email',
  'contact_phone': 'Contact phone (+91…)',
  'business_type': 'Type of business',
  'legal_name': 'Legal business name',
  'pan': 'PAN',
  'gstin_pan_mismatch': 'GSTIN that matches your PAN',
  'pickup_address': 'Pickup address',
  'bank_account': 'Bank account for payouts',
  'document_pan_card': 'PAN card (document)',
  'document_cancelled_cheque': 'Cancelled cheque (document)',
  'document_gst_certificate': 'GST certificate (document)',
  'title': 'Title (3+ characters)',
  'description': 'Description (20+ characters)',
  'category': 'Category',
  'images': 'At least one photo',
  'variants': 'At least one size with a price',
};
