import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.35,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.surfaceMuted.withOpacity(_animation.value),
            borderRadius: widget.borderRadius ?? AppRadius.chipRadius,
            border: Border.all(
              color: colors.border.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        );
      },
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: context.colors.border.withOpacity(0.6),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: SkeletonBox(borderRadius: BorderRadius.zero)),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBox(
                  width: 50,
                  height: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                SkeletonBox(
                  width: double.infinity,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: 70,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Row(
        children: [
          const SkeletonBox(
            width: 72,
            height: 72,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: double.infinity,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: 100,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 12),
                SkeletonBox(
                  width: 80,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
