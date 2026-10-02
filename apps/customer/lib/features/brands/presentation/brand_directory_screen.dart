import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/features/catalog/domain/entities/seller.dart';
import 'package:clothsy_core/shared/widgets/badges/seller_badge.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/shared/widgets/feedback/error_state_view.dart';
import 'package:clothsy_core/shared/widgets/feedback/skeleton_loader.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';

/// Every brand on Clothsy, most followed first (Blueprint, section 25).
class BrandDirectoryScreen extends ConsumerWidget {
  const BrandDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sellers = ref.watch(sellersProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Brands',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
      ),
      body: sellers.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) =>
              const SkeletonBox(width: double.infinity, height: 92),
        ),
        error: (err, _) => ErrorStateView(
          message: 'We could not load the brands. $err',
          onRetry: () => ref.invalidate(sellersProvider),
        ),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _BrandCard(seller: list[index]),
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final Seller seller;

  const _BrandCard({required this.seller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressableScale(
      onTap: () => context.push('/brand/${seller.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: colors.border.withOpacity(0.8)),
        ),
        child: Row(
          children: [
            SellerAvatar(seller: seller, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          seller.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.h3(color: colors.textPrimary),
                        ),
                      ),
                      if (seller.isVerified) ...[
                        const SizedBox(width: 6),
                        const VerifiedBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    seller.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${seller.city} · ${seller.followersLabel} followers · '
                    '★ ${seller.rating.toStringAsFixed(1)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(color: colors.textSecondary),
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
