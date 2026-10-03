import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/panel_widgets.dart';

/// Sales, top products and Try-On insights (Blueprint section 42).
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final money = CurrencyFormatter.format;
    final sales = ref.watch(salesDailyProvider(_days));
    final top = ref.watch(topProductsProvider(_days));
    final tryOns = ref.watch(tryOnInsightsProvider(_days));
    return PanelPage(
      title: 'Insights',
      subtitle:
          'How your store is doing. Views, add-to-bag and wishlist '
          'numbers arrive with Clothsy Growth tools.',
      onRefresh: () async {
        ref.invalidate(salesDailyProvider(_days));
        ref.invalidate(topProductsProvider(_days));
        ref.invalidate(tryOnInsightsProvider(_days));
      },
      actions: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
            ButtonSegment(value: 90, label: Text('90 days')),
          ],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
      ],
      children: [
        AsyncBody<List<SalesDay>>(
          value: sales,
          onRetry: () => ref.invalidate(salesDailyProvider(_days)),
          builder: (days) {
            final gmv = days.fold(0, (t, d) => t + d.gmv);
            final orders = days.fold(0, (t, d) => t + d.orders);
            final units = days.fold(0, (t, d) => t + d.units);
            final label = DateFormat(_days > 30 ? 'd/M' : 'd');
            return PanelCard(
              title: 'Sales',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      StatTile(label: 'Sales', value: money(gmv)),
                      StatTile(label: 'Orders', value: '$orders'),
                      StatTile(label: 'Pieces sold', value: '$units'),
                      StatTile(
                        label: 'Average order',
                        value: money(orders == 0 ? 0 : gmv ~/ orders),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  BarChart(
                    bars: [
                      for (final d in days)
                        (
                          label: label.format(d.day),
                          value: d.gmv.toDouble(),
                          tooltip:
                              '${formatDate(d.day)}: ${money(d.gmv)} · '
                              '${d.orders} orders',
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        PanelCard(
          title: 'Top products',
          child: AsyncBody<List<TopProduct>>(
            value: top,
            onRetry: () => ref.invalidate(topProductsProvider(_days)),
            builder: (list) => list.isEmpty
                ? Text(
                    'Your best sellers show here once orders come in.',
                    style: AppTypography.body(color: colors.textSecondary),
                  )
                : ScrollTable(
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Pieces'), numeric: true),
                      DataColumn(label: Text('Sales'), numeric: true),
                    ],
                    rows: [
                      for (final p in list)
                        DataRow(
                          cells: [
                            DataCell(Text(p.title)),
                            DataCell(Text('${p.units}')),
                            DataCell(Text(money(p.gmv))),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
        PanelCard(
          title: 'Clothsy AI Try-On',
          child: AsyncBody<List<TryOnInsight>>(
            value: tryOns,
            onRetry: () => ref.invalidate(tryOnInsightsProvider(_days)),
            builder: (list) => list.isEmpty
                ? Text(
                    'When shoppers try your products on, you see which ones '
                    'and how many of them go on to buy. Ask for Try-On on a '
                    'product to take part.',
                    style: AppTypography.body(color: colors.textSecondary),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Counts only — Clothsy never shares who tried what.',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ScrollTable(
                        columns: const [
                          DataColumn(label: Text('Product')),
                          DataColumn(label: Text('Try-ons'), numeric: true),
                          DataColumn(label: Text('Shoppers'), numeric: true),
                          DataColumn(label: Text('Bought it'), numeric: true),
                          DataColumn(label: Text('Conversion'), numeric: true),
                        ],
                        rows: [
                          for (final t in list)
                            DataRow(
                              cells: [
                                DataCell(Text(t.title)),
                                DataCell(Text('${t.tryOns}')),
                                DataCell(Text('${t.shoppers}')),
                                DataCell(Text('${t.buyers}')),
                                DataCell(
                                  Text(
                                    '${(t.conversion * 100).toStringAsFixed(0)}%',
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
