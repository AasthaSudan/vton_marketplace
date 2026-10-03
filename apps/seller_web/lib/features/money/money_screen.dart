import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/files.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/panel_widgets.dart';

String _csvCell(Object? v) {
  final s = '${v ?? ''}';
  return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _rupees(int paise) => (paise / 100).toStringAsFixed(2);

/// A statement as CSV (Blueprint section 41: gross sales, platform fee,
/// shipping & collection fees, taxes, refunds and net payout), amounts in
/// rupees.
String buildStatementCsv(
  List<Settlement> settlements,
  List<Adjustment> adjustments,
) {
  final day = DateFormat('yyyy-MM-dd');
  final rows = <List<Object?>>[
    [
      'Type',
      'Reference',
      'Delivered',
      'Gross sales',
      'Platform fee',
      'Shipping fee',
      'Collection fee',
      'GST on fees',
      'Net',
      'Status',
      'Payout',
    ],
    for (final s in settlements)
      [
        'Order',
        s.reference,
        day.format(s.deliveredAt),
        _rupees(s.gross),
        _rupees(-s.commission),
        _rupees(-s.shippingFee),
        _rupees(-s.collectionFee),
        _rupees(-s.gstOnFees),
        _rupees(s.net),
        settlementStatuses[s.status] ?? s.status,
        s.payoutId ?? '',
      ],
    for (final a in adjustments)
      [
        'Adjustment',
        a.reason,
        day.format(a.createdAt),
        '',
        '',
        '',
        '',
        '',
        _rupees(a.amount),
        a.payoutId == null ? 'Next payout' : 'In a payout',
        a.payoutId ?? '',
      ],
  ];
  return '${rows.map((r) => r.map(_csvCell).join(',')).join('\n')}\n';
}

/// Payouts and statements (Blueprint section 41).
class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final money = CurrencyFormatter.format;
    final settlements = ref.watch(settlementsProvider);
    final payouts = ref.watch(payoutsProvider);
    final adjustments = ref.watch(adjustmentsProvider).value ?? const [];
    final bank = ref.watch(bankAccountProvider).value;
    return PanelPage(
      title: 'Money',
      subtitle:
          'Each delivered order is paid out once its return window closes, '
          'to your verified bank account.',
      onRefresh: () async {
        ref.invalidate(settlementsProvider);
        ref.invalidate(payoutsProvider);
        ref.invalidate(adjustmentsProvider);
        ref.invalidate(bankAccountProvider);
      },
      actions: [
        OutlinedButton.icon(
          onPressed: settlements.hasValue
              ? () => ref.read(saveTextProvider)(
                  'clothsy-statement-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
                  buildStatementCsv(settlements.value!, adjustments),
                )
              : null,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Download statement'),
        ),
      ],
      children: [
        AsyncBody<List<Settlement>>(
          value: settlements,
          onRetry: () => ref.invalidate(settlementsProvider),
          builder: (list) {
            int sum(String status) => list
                .where((s) => s.status == status)
                .fold(0, (t, s) => t + s.net);
            final paid = (payouts.value ?? const <Payout>[])
                .where((p) => p.status == 'paid')
                .fold(0, (t, p) => t + p.amount);
            final deductions = adjustments
                .where((a) => a.payoutId == null)
                .fold(0, (t, a) => t + a.amount);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatTile(
                      label: 'In return window',
                      value: money(sum('pending')),
                      hint: 'not yet payable',
                    ),
                    StatTile(
                      label: 'Ready for payout',
                      value: money(sum('eligible')),
                      color: colors.success,
                      hint: 'paid in the next daily run',
                    ),
                    StatTile(
                      label: 'Paid out',
                      value: money(paid),
                      hint: 'all time',
                    ),
                    if (deductions != 0)
                      StatTile(
                        label: 'To be deducted',
                        value: money(deductions),
                        color: colors.error,
                        hint: 'e.g. returns after a payout',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                PanelCard(
                  title: 'Payout account',
                  trailing: TextButton(
                    onPressed: () => context.go('/business'),
                    child: const Text('Change'),
                  ),
                  child: Text(
                    bank == null
                        ? 'No payout account yet — add one in Business details.'
                        : '${bank.accountHolder} · ••••${bank.last4} · '
                              '${bank.ifsc}${bank.status == 'verified' ? '' : ' — not verified yet, payouts are paused'}',
                    style: AppTypography.bodyMedium(
                      color: bank?.status == 'verified'
                          ? colors.textPrimary
                          : colors.warning,
                    ),
                  ),
                ),
                PanelCard(
                  title: 'Payouts',
                  child: AsyncBody<List<Payout>>(
                    value: payouts,
                    onRetry: () => ref.invalidate(payoutsProvider),
                    builder: (ps) => ps.isEmpty
                        ? Text(
                            'Your first payout follows the return window of '
                            'your first delivered order.',
                            style: AppTypography.body(
                              color: colors.textSecondary,
                            ),
                          )
                        : ScrollTable(
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Amount'), numeric: true),
                              DataColumn(label: Text('Orders'), numeric: true),
                              DataColumn(label: Text('To')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Bank reference (UTR)')),
                            ],
                            rows: [
                              for (final p in ps)
                                DataRow(
                                  cells: [
                                    DataCell(Text(formatDate(p.createdAt))),
                                    DataCell(Text(money(p.amount))),
                                    DataCell(Text('${p.settlementCount}')),
                                    DataCell(Text('••••${p.accountLast4}')),
                                    DataCell(
                                      StatusChip(
                                        payoutStatuses[p.status] ?? p.status,
                                        tone: switch (p.status) {
                                          'paid' => Tone.success,
                                          'failed' => Tone.danger,
                                          _ => Tone.info,
                                        },
                                      ),
                                    ),
                                    DataCell(Text(p.utr ?? '—')),
                                  ],
                                ),
                            ],
                          ),
                  ),
                ),
                PanelCard(
                  title: 'Orders and what you earn',
                  child: list.isEmpty
                      ? Text(
                          'Delivered orders show here with every fee worked '
                          'out: item value, less Clothsy\'s commission, '
                          'shipping, payment collection and GST on those fees.',
                          style: AppTypography.body(
                            color: colors.textSecondary,
                          ),
                        )
                      : ScrollTable(
                          columns: const [
                            DataColumn(label: Text('Order')),
                            DataColumn(label: Text('Delivered')),
                            DataColumn(
                              label: Text('Item value'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('Commission'),
                              numeric: true,
                            ),
                            DataColumn(label: Text('Shipping'), numeric: true),
                            DataColumn(
                              label: Text('Collection'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('GST on fees'),
                              numeric: true,
                            ),
                            DataColumn(label: Text('You get'), numeric: true),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: [
                            for (final s in list)
                              DataRow(
                                cells: [
                                  DataCell(Text(s.reference)),
                                  DataCell(Text(formatDate(s.deliveredAt))),
                                  DataCell(Text(money(s.gross))),
                                  DataCell(Text('– ${money(s.commission)}')),
                                  DataCell(Text('– ${money(s.shippingFee)}')),
                                  DataCell(Text('– ${money(s.collectionFee)}')),
                                  DataCell(Text('– ${money(s.gstOnFees)}')),
                                  DataCell(
                                    Text(
                                      money(s.net),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      s.status == 'pending'
                                          ? 'Payable ${formatDate(s.eligibleAt)}'
                                          : settlementStatuses[s.status] ??
                                                s.status,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                ),
                if (adjustments.isNotEmpty)
                  PanelCard(
                    title: 'Adjustments',
                    child: Column(
                      children: [
                        for (final a in adjustments)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(a.reason),
                            subtitle: Text(formatDate(a.createdAt)),
                            trailing: Text(
                              money(a.amount),
                              style: TextStyle(
                                color: a.amount < 0
                                    ? colors.error
                                    : colors.success,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
