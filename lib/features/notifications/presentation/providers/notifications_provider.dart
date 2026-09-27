import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/app_notification.dart';

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    return [
      AppNotification(
        id: 'notif_1',
        title: 'Order Shipped with BlueDart',
        message: 'Your Linen Tailored Blazer (Order #CLY-84920) is on its way.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        type: NotificationType.order,
        deepLink: '/orders/ord_101',
      ),
      AppNotification(
        id: 'notif_2',
        title: 'Exclusive Offer: 20% Off Silk Edits',
        message:
            'Use code LUXURY20 to get 20% off on all Mulberry silk evening gowns.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: NotificationType.promotion,
        deepLink: '/explore',
      ),
      AppNotification(
        id: 'notif_3',
        title: 'Clothsy AI Virtual Try-On Ready',
        message:
            'Try on the new Autumn Atelier collection now with your saved shopper model.',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        type: NotificationType.tryon,
        deepLink: '/tryon',
      ),
    ];
  }

  void markAsRead(String id) {
    state = state
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void clearAll() {
    state = [];
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider);
  return list.where((n) => !n.isRead).length;
});
