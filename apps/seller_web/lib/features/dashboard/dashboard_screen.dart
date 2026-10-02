import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/panel_widgets.dart';

/// Today's work, sales, products, money and performance at a glance.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(currentSellerProvider).value;
    final dashboard = ref.watch(dashboardProvider);
    return PanelPage(
      title: 'Hello, ${seller?.name ?? ''}',
      subtitle: "Here's what needs you today.",
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        ref.invalidate(salesDailyProvider(14));
      },
      children: [
        AsyncBody<SellerDashboard>(
          value: dashboard,
          onRetry: () => ref.invalidate(dashboardProvider),
          builder: (d) => _Dashboard(d: d),
        ),
      ],
    );
  }
}

class _Dashboard extends ConsumerWidget {
  final SellerDashboard d;

  const _Dashboard({required this.d});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final money = CurrencyFormatter.format;
    final score = d.performanceScore;
    final sales = ref.watch(salesDailyProvider(14)).value ?? const [];
    final dayLabel = DateFormat('d');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          title: 'Orders',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'New — accept',
                value: '${d.newOrders}',
                icon: Icons.fiber_new_rounded,
                onTap: () => context.go('/orders?tab=new'),
              ),
              StatTile(
                label: 'To pack',
                value: '${d.toPack}',
                icon: Icons.inventory_rounded,
                onTap: () => context.go('/orders?tab=pack'),
              ),
              StatTile(
                label: 'To ship',
                value: '${d.toShip}',
                icon: Icons.local_shipping_rounded,
                onTap: () => context.go('/orders?tab=ship'),
              ),
              StatTile(
                label: 'Late to dispatch',
                value: '${d.late}',
                icon: Icons.schedule_rounded,
                color: d.late > 0 ? colors.error : colors.success,
                onTap: () => context.go('/orders?tab=new'),
              ),
              StatTile(
                label: 'In transit',
                value: '${d.inTransit}',
                icon: Icons.route_rounded,
              ),
              StatTile(
                label: 'Today',
                value: '${d.ordersToday}',
                hint: 'orders received',
                icon: Icons.today_rounded,
              ),
            ],
          ),
        ),
        PanelCard(
          title: 'Sales — last 30 days',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  StatTile(label: 'Sales', value: money(d.sales30dGmv)),
                  StatTile(label: 'Orders', value: '${d.sales30dOrders}'),
                  StatTile(label: 'Pieces sold', value: '${d.sales30dUnits}'),
                  StatTile(label: 'Average order', value: money(d.sales30dAov)),
                ],
              ),
              if (sales.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Last 14 days',
                  style: AppTypography.label(color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                BarChart(
                  bars: [
                    for (final s in sales)
                      (
                        label: dayLabel.format(s.day),
                        value: s.gmv.toDouble(),
                        tooltip:
                            '${formatDate(s.day)}: ${money(s.gmv)} · '
                            '${s.orders} orders',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        PanelCard(
          title: 'Products and stock',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'Live',
                value: '${d.products['live'] ?? 0}',
                color: colors.success,
                onTap: () => context.go('/products'),
              ),
              StatTile(
                label: 'In review',
                value: '${d.products['in_review'] ?? 0}',
                onTap: () => context.go('/products'),
              ),
              StatTile(
                label: 'Changes needed',
                value: '${d.products['rejected'] ?? 0}',
                color: (d.products['rejected'] ?? 0) > 0
                    ? colors.warning
                    : null,
                onTap: () => context.go('/products'),
              ),
              StatTile(
                label: 'Drafts',
                value: '${d.products['drafts'] ?? 0}',
                onTap: () => context.go('/products'),
              ),
              StatTile(
                label: 'Low stock',
                value: '${d.lowStock}',
                hint: 'sizes running out',
                color: d.lowStock > 0 ? colors.warning : colors.success,
                onTap: () => context.go('/inventory?low=1'),
              ),
            ],
          ),
        ),
        PanelCard(
          title: 'Money',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'In return window',
                value: money(d.moneyPending),
                hint: 'paid out after returns close',
                onTap: () => context.go('/money'),
              ),
              StatTile(
                label: 'Ready for payout',
                value: money(d.moneyEligible),
                color: colors.success,
                onTap: () => context.go('/money'),
              ),
              StatTile(
                label: 'Last payout',
                value: d.lastPayoutAmount == null
                    ? '—'
                    : money(d.lastPayoutAmount!),
                hint: d.lastPayoutStatus == null
                    ? 'none yet'
                    : payoutStatuses[d.lastPayoutStatus],
                onTap: () => context.go('/money'),
              ),
            ],
          ),
        ),
        PanelCard(
          title: 'Performance (90 days)',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'Score',
                value: score == null ? '—' : '$score / 100',
                hint: score == null ? 'after your first orders' : null,
                color: score == null || score >= 80
                    ? colors.success
                    : score >= 60
                    ? colors.warning
                    : colors.error,
              ),
              StatTile(
                label: 'Cancelled by you',
                value: '${(d.cancellationRate * 100).toStringAsFixed(1)}%',
                hint: 'keep this under 2%',
              ),
              StatTile(
                label: 'Dispatched late',
                value: '${(d.lateDispatchRate * 100).toStringAsFixed(1)}%',
                hint: 'ship by the promised date',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
