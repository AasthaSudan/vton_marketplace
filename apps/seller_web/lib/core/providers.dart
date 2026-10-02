import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/seller_repository.dart';

/// Set in main (Supabase) and in tests (a fake).
final sellerRepositoryProvider = Provider<SellerRepository>(
  (ref) => throw UnimplementedError('sellerRepositoryProvider is overridden'),
);

/// Whether someone is signed in; follows sign-in / sign-out / expiry.
final signedInProvider = NotifierProvider<SignedInNotifier, bool>(
  SignedInNotifier.new,
);

class SignedInNotifier extends Notifier<bool> {
  @override
  bool build() {
    final repo = ref.watch(sellerRepositoryProvider);
    final sub = repo.signedInChanges.listen((signedIn) {
      if (signedIn != state) state = signedIn;
    });
    ref.onDispose(sub.cancel);
    return repo.isSignedIn;
  }

  /// After signing in or out through the repository (streams can lag).
  void refresh() => state = ref.read(sellerRepositoryProvider).isSignedIn;
}

/// The store the signed-in user works for (their first), or null.
final currentSellerProvider = FutureProvider<SellerContext?>((ref) async {
  if (!ref.watch(signedInProvider)) return null;
  final sellers = await ref.watch(sellerRepositoryProvider).mySellers();
  return sellers.isEmpty ? null : sellers.first;
});

/// For screens behind the gate: the store is loaded by then.
Future<String> _sellerId(Ref ref) async {
  final seller = await ref.watch(currentSellerProvider.future);
  if (seller == null) throw const SellerFailure('SELLER_NOT_FOUND');
  return seller.sellerId;
}

SellerRepository _repo(Ref ref) => ref.watch(sellerRepositoryProvider);

final applicationProvider = FutureProvider.autoDispose<SellerApplication>(
  (ref) async => _repo(ref).application(await _sellerId(ref)),
);
final bankAccountProvider = FutureProvider.autoDispose<BankAccount?>(
  (ref) async => _repo(ref).bankAccount(await _sellerId(ref)),
);
final documentsProvider = FutureProvider.autoDispose<List<SellerDocument>>(
  (ref) async => _repo(ref).documents(await _sellerId(ref)),
);
final applicationHistoryProvider =
    FutureProvider.autoDispose<List<ApplicationEvent>>(
      (ref) async => _repo(ref).applicationHistory(await _sellerId(ref)),
    );

final dashboardProvider = FutureProvider.autoDispose<SellerDashboard>(
  (ref) async => _repo(ref).dashboard(await _sellerId(ref)),
);
final productsProvider = FutureProvider.autoDispose<List<SellerProduct>>(
  (ref) async => _repo(ref).products(await _sellerId(ref)),
);
final productProvider = FutureProvider.autoDispose
    .family<SellerProduct, String>((ref, id) async => _repo(ref).product(id));
final stockHistoryProvider = FutureProvider.autoDispose<List<StockMovement>>(
  (ref) async => _repo(ref).stockHistory(await _sellerId(ref)),
);
final ordersProvider = FutureProvider.autoDispose<List<SellerOrder>>(
  (ref) async => _repo(ref).orders(await _sellerId(ref)),
);
final storefrontProvider = FutureProvider.autoDispose<Storefront>(
  (ref) async => _repo(ref).storefront(await _sellerId(ref)),
);
final collectionsProvider = FutureProvider.autoDispose<List<SellerCollection>>(
  (ref) async => _repo(ref).collections(await _sellerId(ref)),
);
final settlementsProvider = FutureProvider.autoDispose<List<Settlement>>(
  (ref) async => _repo(ref).settlements(await _sellerId(ref)),
);
final payoutsProvider = FutureProvider.autoDispose<List<Payout>>(
  (ref) async => _repo(ref).payouts(await _sellerId(ref)),
);
final adjustmentsProvider = FutureProvider.autoDispose<List<Adjustment>>(
  (ref) async => _repo(ref).adjustments(await _sellerId(ref)),
);
final salesDailyProvider = FutureProvider.autoDispose
    .family<List<SalesDay>, int>(
      (ref, days) async =>
          _repo(ref).salesDaily(await _sellerId(ref), days: days),
    );
final topProductsProvider = FutureProvider.autoDispose
    .family<List<TopProduct>, int>(
      (ref, days) async =>
          _repo(ref).topProducts(await _sellerId(ref), days: days),
    );
final tryOnInsightsProvider = FutureProvider.autoDispose
    .family<List<TryOnInsight>, int>(
      (ref, days) async =>
          _repo(ref).tryOnInsights(await _sellerId(ref), days: days),
    );
