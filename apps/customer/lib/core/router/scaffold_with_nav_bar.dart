import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/shared/widgets/navigation/clothsy_bottom_nav.dart';
import '../../features/cart/presentation/providers/cart_provider.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bagCount = ref.watch(cartCountProvider);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: ClothsyBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(context, index),
        badgeCounts: {ClothsyBottomNav.bagIndex: bagCount},
      ),
    );
  }
}
