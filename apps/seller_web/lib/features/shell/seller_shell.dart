import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/navigation/panel_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router.dart';

/// The panel around every section: sidebar (drawer on narrow screens) with
/// the store and a sign-out button.
class SellerShell extends ConsumerWidget {
  final String location;
  final Widget child;

  const SellerShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = sellerSections.indexWhere(
      (s) => location == s.path || location.startsWith('${s.path}/'),
    );
    return PanelShell(
      panelName: 'Seller Panel',
      sections: [for (final s in sellerSections) s.panel],
      selectedIndex: index < 0 ? 0 : index,
      onSelect: (i) => context.go(sellerSections[i].path),
      body: child,
      sidebarFooter: const _StoreFooter(),
    );
  }
}

class _StoreFooter extends ConsumerWidget {
  const _StoreFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final store = ref.watch(currentSellerProvider).value;
    final email = ref.watch(sellerRepositoryProvider).userEmail;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            store?.name ?? '',
            style: AppTypography.bodyMedium(
              color: colors.textPrimary,
              weight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (email != null)
            Text(
              email,
              style: AppTypography.caption(color: colors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await ref.read(sellerRepositoryProvider).signOut();
              ref.read(signedInProvider.notifier).refresh();
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
