import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:clothsy_core/shared/widgets/feedback/empty_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/panel_widgets.dart';

/// Tone of a listing's status chip.
Tone productTone(String status) => switch (status) {
  'live' => Tone.success,
  'pending_review' => Tone.info,
  'rejected' => Tone.warning,
  _ => Tone.neutral,
};

/// Every listing by status (Blueprint fig. 33): drafts, in review, changes
/// needed, live and unpublished.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  static const filters = [
    ('All', <String>{}),
    ('Live', {'live'}),
    ('In review', {'pending_review'}),
    ('Changes needed', {'rejected'}),
    ('Drafts', {'draft'}),
    ('Unpublished', {'archived'}),
  ];

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    return PanelPage(
      title: 'Products',
      subtitle:
          'Every listing is checked by Clothsy before it goes live; you can '
          'unpublish it any time.',
      onRefresh: () async => ref.invalidate(productsProvider),
      actions: [
        FilledButton.icon(
          onPressed: () => context.go('/products/new'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add product'),
        ),
      ],
      children: [
        AsyncBody<List<SellerProduct>>(
          value: products,
          onRetry: () => ref.invalidate(productsProvider),
          builder: (all) {
            final set = ProductsScreen.filters[_filter].$2;
            final shown = set.isEmpty
                ? all
                : all.where((p) => set.contains(p.status)).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < ProductsScreen.filters.length; i++)
                      ChoiceChip(
                        label: Text(
                          '${ProductsScreen.filters[i].$1} '
                          '(${ProductsScreen.filters[i].$2.isEmpty ? all.length : all.where((p) => ProductsScreen.filters[i].$2.contains(p.status)).length})',
                        ),
                        selected: i == _filter,
                        onSelected: (_) => setState(() => _filter = i),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (shown.isEmpty)
                  EmptyStateView(
                    icon: Icons.checkroom_outlined,
                    title: all.isEmpty ? 'No products yet' : 'Nothing here',
                    message: all.isEmpty
                        ? 'Add your first product: photos, sizes, prices and '
                              'stock. Clothsy reviews it before it goes live.'
                        : 'Listings with this status will show up here.',
                    actionText: all.isEmpty ? 'Add product' : null,
                    onActionPressed: all.isEmpty
                        ? () => context.go('/products/new')
                        : null,
                  )
                else
                  for (final p in shown) _ProductRow(product: p),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  final SellerProduct product;

  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final p = product;
    return PanelCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => context.go('/products/${p.id}'),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 54,
                height: 72,
                child: p.images.isEmpty
                    ? ColoredBox(
                        color: colors.surfaceMuted,
                        child: Icon(
                          Icons.image_outlined,
                          color: colors.textSecondary,
                        ),
                      )
                    : Image.network(
                        p.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: colors.surfaceMuted),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        p.title,
                        style: AppTypography.bodyMedium(
                          color: colors.textPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      StatusChip(
                        productStatuses[p.status] ?? p.status,
                        tone: productTone(p.status),
                      ),
                      if (p.isTryOnEligible)
                        const StatusChip('Try-On', tone: Tone.info),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (p.category.isNotEmpty) p.category,
                      if (p.minPrice > 0)
                        'from ${CurrencyFormatter.format(p.minPrice)}',
                      '${p.variants.length} size${p.variants.length == 1 ? '' : 's'}',
                      '${p.totalStock} in stock',
                    ].join(' · '),
                    style: AppTypography.caption(color: colors.textSecondary),
                  ),
                  if (p.status == 'rejected' && p.rejectionReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Clothsy: ${p.rejectionReason}',
                        style: AppTypography.caption(color: colors.warning),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
