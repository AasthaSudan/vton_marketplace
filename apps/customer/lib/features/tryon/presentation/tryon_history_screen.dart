import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:clothsy_shop/features/cart/presentation/providers/cart_provider.dart';
import 'package:clothsy_core/shared/widgets/buttons/clothsy_icon_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import 'package:clothsy_core/shared/widgets/feedback/empty_state_view.dart';
import 'providers/tryon_provider.dart';

class TryOnHistoryScreen extends ConsumerWidget {
  const TryOnHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final history = ref.watch(tryOnHistoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'My Try-On Looks',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
        leading: ClothsyIconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              onPressed: () {
                _confirmClearHistory(context, ref);
              },
              child: Text(
                'Clear All',
                style: AppTypography.caption(
                  color: colors.error,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: EmptyStateView(
                title: 'No Try-On Looks Yet',
                message:
                    'Try on pieces from your favourite brands to see yourself styled in seconds.',
                icon: Icons.auto_awesome,
                actionText: 'Open Try-On Studio',
                onActionPressed: () => Navigator.pop(context),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: history.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final item = history[index];

                return Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preview Image
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: item.resultImageUrl,
                              fit: BoxFit.cover,
                            ),
                            // Delete button
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(tryOnHistoryProvider.notifier)
                                        .deleteItem(item.id);
                                    ClothsySnackbar.show(
                                      context,
                                      message: 'Look removed from history',
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Model photo circular thumbnail
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: CachedNetworkImage(
                                  imageUrl: item.photo.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Item Details
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium(
                                weight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.format(item.variant.price),
                              style: AppTypography.price(
                                color: colors.textPrimary,
                              ).copyWith(fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            // Direct Add To Bag Button
                            PressableScale(
                              onTap: () {
                                ref
                                    .read(cartProvider.notifier)
                                    .addToCart(item.product, item.variant);
                                ClothsySnackbar.show(
                                  context,
                                  message: 'Added ${item.product.title} to bag',
                                );
                                context.go('/bag');
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: AppRadius.buttonRadius,
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Add to Bag',
                                        style:
                                            AppTypography.caption(
                                              color: Colors.white,
                                            ).copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Look History?',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
        content: Text(
          'This will permanently remove all your saved AI virtual try-on looks.',
          style: AppTypography.body(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(tryOnHistoryProvider.notifier).clearAll();
              ClothsySnackbar.show(context, message: 'Try-on history cleared');
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
