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
import 'order_actions.dart';

/// Orders by what needs doing (Blueprint fig. 34).
class OrdersScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const OrdersScreen({super.key, this.initialTab});

  static const tabs = [
    ('new', 'New', {'placed'}),
    ('pack', 'To pack', {'confirmed'}),
    ('ship', 'To ship', {'packed'}),
    ('transit', 'In transit', {'shipped', 'out_for_delivery'}),
    ('delivered', 'Delivered', {'delivered'}),
    ('closed', 'Cancelled & returned', {'cancelled', 'returned'}),
  ];

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late int _tab = OrdersScreen.tabs
      .indexWhere((t) => t.$1 == widget.initialTab)
      .clamp(0, OrdersScreen.tabs.length - 1);

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    return PanelPage(
      title: 'Orders',
      subtitle:
          'Accept, pack, ship — the shopper is kept informed at each step.',
      onRefresh: () async => ref.invalidate(ordersProvider),
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(ordersProvider),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      ],
      children: [
        AsyncBody<List<SellerOrder>>(
          value: orders,
          onRetry: () => ref.invalidate(ordersProvider),
          builder: (all) {
            final counts = [
              for (final t in OrdersScreen.tabs)
                all.where((o) => t.$3.contains(o.status)).length,
            ];
            final shown = all
                .where((o) => OrdersScreen.tabs[_tab].$3.contains(o.status))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < OrdersScreen.tabs.length; i++)
                      ChoiceChip(
                        label: Text(
                          '${OrdersScreen.tabs[i].$2} (${counts[i]})',
                        ),
                        selected: i == _tab,
                        onSelected: (_) => setState(() => _tab = i),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (shown.isEmpty)
                  const EmptyStateView(
                    icon: Icons.inbox_outlined,
                    title: 'Nothing here',
                    message: 'Orders in this step will show up here.',
                  )
                else
                  for (final o in shown) OrderCard(order: o),
              ],
            );
          },
        ),
      ],
    );
  }
}

class OrderCard extends ConsumerWidget {
  final SellerOrder order;

  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final actions = OrderActions(context);
    final next = nextStepButton(actions, order);
    final late = order.isLate(DateTime.now());
    final summary = order.items
        .map((i) => '${i.quantity} × ${i.title} (${i.size})')
        .join(', ');
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => context.go('/orders/${order.id}'),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        order.reference,
                        style: AppTypography.h3(color: colors.textPrimary),
                      ),
                      StatusChip(
                        orderStatuses[order.status] ?? order.status,
                        tone: order.status == 'cancelled'
                            ? Tone.danger
                            : order.status == 'delivered'
                            ? Tone.success
                            : Tone.info,
                      ),
                      if (late) const StatusChip('Late', tone: Tone.danger),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: AppTypography.body(color: colors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${CurrencyFormatter.format(order.total)} · ordered '
                    '${formatDateTime(order.createdAt)}'
                    '${order.isOpen ? ' · dispatch by ${formatDate(order.dispatchBy)}' : ''}',
                    style: AppTypography.caption(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            ?next,
          ],
        ),
      ),
    );
  }
}
