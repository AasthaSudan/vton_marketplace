import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/buttons/clothsy_icon_button.dart';
import '../../../shared/widgets/buttons/pressable_scale.dart';
import '../../../shared/widgets/feedback/empty_state_view.dart';
import '../domain/entities/app_notification.dart';
import 'providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ClothsyIconButton(
            size: 38,
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: colors.primary),
            onPressed: () => context.pop(),
          ),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
              child: Text(
                'Mark All Read',
                style: AppTypography.caption(color: colors.primary, weight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? EmptyStateView(
              icon: Icons.notifications_none_rounded,
              title: 'No Notifications',
              message: 'We will notify you here with tracking milestones, price drop alerts, and try-on updates.',
              actionText: 'Back to Home',
              onActionPressed: () => context.go('/'),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _buildNotificationCard(context, ref, notif);
              },
            ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    AppNotification notif,
  ) {
    final colors = context.colors;
    final timeStr = DateFormat('dd MMM, hh:mm a').format(notif.timestamp);

    IconData icon;
    Color iconBg;
    switch (notif.type) {
      case NotificationType.order:
        icon = Icons.local_shipping_outlined;
        iconBg = colors.accentSoft;
        break;
      case NotificationType.promotion:
        icon = Icons.discount_outlined;
        iconBg = colors.surfaceMuted;
        break;
      case NotificationType.tryon:
        icon = Icons.auto_awesome;
        iconBg = colors.accentSoft;
        break;
      case NotificationType.alert:
        icon = Icons.info_outline;
        iconBg = colors.surfaceMuted;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onTap: () {
          ref.read(notificationsProvider.notifier).markAsRead(notif.id);
          if (notif.deepLink != null) {
            context.push(notif.deepLink!);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notif.isRead ? colors.surface : colors.surfaceMuted.withOpacity(0.5),
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: notif.isRead ? colors.border.withOpacity(0.5) : colors.accent.withOpacity(0.6),
              width: notif.isRead ? 0.8 : 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: AppTypography.bodyMedium(
                              weight: notif.isRead ? FontWeight.w600 : FontWeight.w700,
                              color: colors.textPrimary,
                            ).copyWith(fontSize: 14),
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.message,
                      style: AppTypography.body(color: colors.textSecondary).copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeStr,
                      style: AppTypography.caption(color: colors.textSecondary).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
