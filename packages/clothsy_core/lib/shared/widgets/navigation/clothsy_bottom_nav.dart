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

/// Five-tab bottom bar with Clothsy AI at the centre (Brand Blueprint,
/// section 21): Home · Explore · Clothsy AI · Bag · Profile.
class ClothsyBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Badge count per tab index, e.g. `{bagIndex: 3}`.
  final Map<int, int> badgeCounts;

  static const int homeIndex = 0;
  static const int exploreIndex = 1;
  static const int clothsyAiIndex = 2;
  static const int bagIndex = 3;
  static const int profileIndex = 4;

  const ClothsyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.badgeCounts = const {},
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
      label: 'Clothsy AI',
      isSpecial: true,
    ),
    ClothsyNavItem(
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag_rounded,
      label: 'Bag',
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
              final badgeCount = badgeCounts[index] ?? item.badgeCount;

              if (item.isSpecial) {
                // Clothsy AI centre tab — Try-On Coral marks every AI moment.
                return PressableScale(
                  onTap: () => onTap(index),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [colors.primary, colors.tryOn],
                                  )
                                : null,
                            color: isSelected ? null : colors.tryOnSoft,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colors.tryOn.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            item.activeIcon,
                            size: 18,
                            color: isSelected ? colors.onPrimary : colors.tryOn,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          style: AppTypography.label(
                            color: isSelected
                                ? colors.tryOn
                                : colors.textSecondary.withOpacity(0.8),
                            weight: FontWeight.w600,
                          ).copyWith(fontSize: 10, height: 1.2),
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
                          if (badgeCount > 0)
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
                                  badgeCount > 9 ? '9+' : '$badgeCount',
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
                        maxLines: 1,
                        style: AppTypography.label(
                          color: isSelected
                              ? colors.primary
                              : colors.textSecondary.withOpacity(0.8),
                          weight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ).copyWith(fontSize: 10, height: 1.2),
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
