import 'package:clothsy_core/shared/widgets/navigation/panel_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/sign_in_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/money/money_screen.dart';
import '../features/onboarding/application_screen.dart';
import '../features/onboarding/register_brand_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/products/product_editor_screen.dart';
import '../features/products/products_screen.dart';
import '../features/shell/loading_screen.dart';
import '../features/shell/seller_shell.dart';
import '../features/store/store_screen.dart';
import 'providers.dart';

/// Sidebar sections (Blueprint fig. 30) and where they live.
class SellerSection {
  final PanelSection panel;
  final String path;

  const SellerSection(this.panel, this.path);
}

const sellerSections = [
  SellerSection(
    PanelSection(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      items: ['Sales & revenue', "Today's orders", 'Alerts & tasks'],
      phase: 'Phase 2',
    ),
    '/dashboard',
  ),
  SellerSection(
    PanelSection(
      title: 'Orders',
      icon: Icons.local_shipping_outlined,
      items: ['New orders', 'Packing & labels', 'Pickups & tracking'],
      phase: 'Phase 2',
    ),
    '/orders',
  ),
  SellerSection(
    PanelSection(
      title: 'Products',
      icon: Icons.checkroom_outlined,
      items: ['Add / edit products', 'Drafts', 'Approval status'],
      phase: 'Phase 2',
    ),
    '/products',
  ),
  SellerSection(
    PanelSection(
      title: 'Inventory',
      icon: Icons.inventory_2_outlined,
      items: ['Stock by SKU', 'Low-stock alerts', 'Bulk upload'],
      phase: 'Phase 2',
    ),
    '/inventory',
  ),
  SellerSection(
    PanelSection(
      title: 'Store',
      icon: Icons.storefront_outlined,
      items: ['Storefront design', 'Collections', 'Brand story', 'Policies'],
      phase: 'Phase 2',
    ),
    '/store',
  ),
  SellerSection(
    PanelSection(
      title: 'Money',
      icon: Icons.account_balance_wallet_outlined,
      items: ['Payouts', 'Statements'],
      phase: 'Phase 2',
    ),
    '/money',
  ),
  SellerSection(
    PanelSection(
      title: 'Insights',
      icon: Icons.insights_outlined,
      items: ['Analytics', 'Top products', 'Try-On insights'],
      phase: 'Phase 2',
    ),
    '/insights',
  ),
  SellerSection(
    PanelSection(
      title: 'Business details',
      icon: Icons.verified_user_outlined,
      items: ['Business & tax details', 'KYC & bank details'],
      phase: 'Phase 2',
    ),
    '/business',
  ),
  SellerSection(
    PanelSection(
      title: 'Growth',
      icon: Icons.campaign_outlined,
      items: [
        'Coupons & offers',
        'Flash sales',
        'Campaigns',
        'Reviews & replies',
      ],
      phase: 'Phase 4',
    ),
    '/growth',
  ),
];

/// Where a signed-in user belongs, given their store (null: none yet).
String? sellerRedirect({
  required bool signedIn,
  required AsyncValue<Object?> seller,
  required bool hasStore,
  required bool isApproved,
  required String path,
}) {
  if (!signedIn) return path == '/sign-in' ? null : '/sign-in';
  if (!seller.hasValue) return path == '/loading' ? null : '/loading';
  if (!hasStore) return path == '/register' ? null : '/register';
  if (!isApproved) return path == '/application' ? null : '/application';
  const entry = {'/sign-in', '/register', '/loading', '/application', '/'};
  return entry.contains(path) ? '/dashboard' : null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(signedInProvider, (_, _) => refresh.value++);
  ref.listen(currentSellerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final seller = ref.read(currentSellerProvider);
      final store = seller.value;
      return sellerRedirect(
        signedIn: ref.read(signedInProvider),
        seller: seller,
        hasStore: store != null,
        isApproved: store?.isApproved ?? false,
        path: state.uri.path,
      );
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/dashboard'),
      GoRoute(path: '/loading', builder: (_, _) => const LoadingScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/register',
        builder: (_, _) => const RegisterBrandScreen(),
      ),
      GoRoute(
        path: '/application',
        builder: (_, _) => const ApplicationScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            SellerShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (_, state) =>
                OrdersScreen(initialTab: state.uri.queryParameters['tab']),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => OrderDetailScreen(
                  sellerOrderId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          // Built next; the sidebar already shows where they will live.
          GoRoute(
            path: '/products',
            builder: (_, _) => const ProductsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const ProductEditorScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    ProductEditorScreen(productId: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/inventory',
            builder: (_, state) => InventoryScreen(
              lowStockOnly: state.uri.queryParameters['low'] == '1',
            ),
          ),
          GoRoute(path: '/store', builder: (_, _) => const StoreScreen()),
          GoRoute(path: '/money', builder: (_, _) => const MoneyScreen()),
          for (final path in const ['/insights'])
            GoRoute(
              path: path,
              builder: (_, _) => PanelSectionPlaceholder(
                section: sellerSections.firstWhere((s) => s.path == path).panel,
              ),
            ),
          GoRoute(
            path: '/business',
            builder: (_, _) => const ApplicationScreen(embedded: true),
          ),
          GoRoute(
            path: '/growth',
            builder: (_, _) =>
                PanelSectionPlaceholder(section: sellerSections.last.panel),
          ),
        ],
      ),
    ],
  );
});
