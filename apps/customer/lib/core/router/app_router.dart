import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/address/presentation/address_list_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/checkout/presentation/order_success_screen.dart';
import '../../features/gallery/presentation/component_gallery_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/tryon/presentation/tryon_history_screen.dart';
import '../../features/tryon/presentation/tryon_screen.dart';
import '../../features/wishlist/presentation/wishlist_screen.dart';
import 'scaffold_with_nav_bar.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _sectionHomeNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'sectionHome',
);
final _sectionExploreNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'sectionExplore',
);
final _sectionTryonNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'sectionTryon',
);
final _sectionWishlistNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'sectionWishlist',
);
final _sectionProfileNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'sectionProfile',
);

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _sectionHomeNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _sectionExploreNavigatorKey,
            routes: [
              GoRoute(
                path: '/explore',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CatalogScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _sectionTryonNavigatorKey,
            routes: [
              GoRoute(
                path: '/tryon',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: TryonScreen(
                    initialProductId: state.uri.queryParameters['productId'],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _sectionWishlistNavigatorKey,
            routes: [
              GoRoute(
                path: '/wishlist',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: WishlistScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _sectionProfileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'];
          return LoginScreen(redirectPath: redirect);
        },
      ),
      GoRoute(
        path: '/otp',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          final redirect = state.uri.queryParameters['redirect'];
          return OtpVerificationScreen(
            phoneNumber: phone,
            redirectPath: redirect,
          );
        },
      ),
      GoRoute(
        path: '/gallery',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ComponentGalleryScreen(),
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/cart',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/checkout',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/order-success/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final orderId = state.pathParameters['id'] ?? '';
          return OrderSuccessScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/orders',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OrdersListScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderDetailScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/addresses',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddressListScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/tryon/history',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TryOnHistoryScreen(),
      ),
      GoRoute(
        path: '/product/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'p1';
          return ProductDetailScreen(productId: id);
        },
      ),
    ],
  );
});
