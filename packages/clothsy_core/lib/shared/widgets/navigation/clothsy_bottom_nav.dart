import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/pressable_scale.dart';

class ClothsyNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSpecial;
  final int badgeCount;

  const ClothsyNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isSpecial = false,
    this.badgeCount = 0,
  });
}

class ClothsyBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ClothsyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<ClothsyNavItem> items = [
    ClothsyNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    ClothsyNavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'Explore',
    ),
    ClothsyNavItem(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome,
      label: 'Try-On',
      isSpecial: true,
    ),
    ClothsyNavItem(
      icon: Icons.favorite_outline_rounded,
      activeIcon: Icons.favorite_rounded,
      label: 'Wishlist',
    ),
    ClothsyNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border.withOpacity(0.6), width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;

              if (item.isSpecial) {
                // Highlighted Try-On AI Center Button
                return PressableScale(
                  onTap: () => onTap(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? [colors.primary, const Color(0xFF4A3468)]
                            : [colors.accentSoft, colors.surfaceMuted],
                      ),
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colors.primary.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.activeIcon,
                          size: 18,
                          color: isSelected ? colors.accent : colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.label,
                          style: AppTypography.label(
                            color: isSelected
                                ? colors.onPrimary
                                : colors.primary,
                            weight: FontWeight.w700,
                          ).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return PressableScale(
                onTap: () => onTap(index),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            size: 24,
                            color: isSelected
                                ? colors.primary
                                : colors.textSecondary.withOpacity(0.8),
                          ),
                          if (item.badgeCount > 0)
                            Positioned(
                              right: -6,
                              top: -3,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 14,
                                  minHeight: 14,
                                ),
                                child: Text(
                                  '${item.badgeCount}',
                                  style: AppTypography.label(
                                    color: colors.onPrimary,
                                  ).copyWith(fontSize: 8),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: AppTypography.label(
                          color: isSelected
                              ? colors.primary
                              : colors.textSecondary.withOpacity(0.8),
                          weight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ).copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
