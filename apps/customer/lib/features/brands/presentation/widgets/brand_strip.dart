import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/features/catalog/domain/entities/seller.dart';
import 'package:clothsy_core/shared/widgets/badges/seller_badge.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/shared/widgets/typography/section_header.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';

/// Home "Shop by brand" row — discovery of independent labels is Clothsy's
/// signature (Brand Blueprint, section 25).
class BrandStrip extends ConsumerWidget {
  const BrandStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellers = ref.watch(sellersProvider);

    return sellers.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeader(
                title: 'Shop by brand',
                actionText: 'See All',
                onActionTap: () => context.push('/brands'),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) =>
                    _BrandTile(seller: list[index]),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _BrandTile extends StatelessWidget {
  final Seller seller;

  const _BrandTile({required this.seller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressableScale(
      onTap: () => context.push('/brand/${seller.id}'),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            SellerAvatar(seller: seller, size: 64),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    seller.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(
                      color: colors.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                if (seller.isVerified) ...[
                  const SizedBox(width: 2),
                  const VerifiedBadge(size: 12),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
