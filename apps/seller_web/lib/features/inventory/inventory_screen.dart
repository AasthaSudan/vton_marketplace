import 'dart:convert';

import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/feedback/empty_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../../data/seller_repository.dart';
import '../../widgets/panel_widgets.dart';

/// Rows of a stock CSV (`sku,stock`, header optional) and the lines that
/// could not be read.
({List<({String sku, int stock})> rows, List<String> errors}) parseStockCsv(
  String text,
) {
  final rows = <({String sku, int stock})>[];
  final errors = <String>[];
  final lines = const LineSplitter().convert(text);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final cells = line.split(RegExp(r'[,;\t]')).map((c) => c.trim()).toList();
    if (i == 0 && cells.first.toLowerCase() == 'sku') continue;
    final stock = cells.length >= 2 ? int.tryParse(cells[1]) : null;
    if (cells.first.isEmpty || stock == null || stock < 0) {
      errors.add('Line ${i + 1}: "$line"');
    } else {
      rows.add((sku: cells.first, stock: stock));
    }
  }
  return (rows: rows, errors: errors);
}

/// Stock by SKU, low-stock alerts, adjustments, bulk import and history
/// (Blueprint fig. 30, Inventory).
class InventoryScreen extends ConsumerStatefulWidget {
  final bool lowStockOnly;

  const InventoryScreen({super.key, this.lowStockOnly = false});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  late bool _lowOnly = widget.lowStockOnly;
  String _query = '';
  bool _importing = false;

  void _refresh() {
    ref.invalidate(productsProvider);
    ref.invalidate(stockHistoryProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _adjust(SellerProduct p, SellerVariant v) async {
    final result = await showDialog<({int delta, String note})>(
      context: context,
      builder: (_) => _AdjustDialog(product: p, variant: v),
    );
    if (result == null) return;
    try {
      final stock = await ref
          .read(sellerRepositoryProvider)
          .adjustStock(v.id, result.delta, note: result.note);
      _refresh();
      if (mounted) showDone(context, '${v.sku}: $stock in stock');
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _import() async {
    final file = await ref.read(pickFileProvider)(['csv', 'txt']);
    if (file == null) return;
    final parsed = parseStockCsv(utf8.decode(file.bytes, allowMalformed: true));
    if (!mounted) return;
    if (parsed.errors.isNotEmpty || parsed.rows.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nothing was imported'),
          content: Text(
            parsed.rows.isEmpty && parsed.errors.isEmpty
                ? 'The file is empty. Use two columns: sku,stock'
                : 'These lines need a SKU and a whole number:\n'
                      '${parsed.errors.take(10).join('\n')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final sure = await confirm(
      context,
      title: 'Set stock for ${parsed.rows.length} SKUs?',
      message:
          'Each number becomes the units available to sell (units already in '
          'open orders are not counted). Nothing changes if any SKU is '
          'unknown.',
      confirmText: 'Import',
    );
    if (!sure) return;
    setState(() => _importing = true);
    try {
      final seller = ref.read(currentSellerProvider).requireValue!;
      final r = await ref
          .read(sellerRepositoryProvider)
          .bulkSetStock(seller.sellerId, parsed.rows);
      _refresh();
      if (mounted) {
        showDone(context, '${r.updated} updated, ${r.unchanged} unchanged');
      }
    } on SellerFailure catch (e) {
      if (!mounted) return;
      final bad = ((e.details['errors'] as List?) ?? const [])
          .map((x) => (x as Map)['sku'] ?? x['error'])
          .join(', ');
      if (bad.isEmpty) {
        showFailure(context, e);
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nothing was imported'),
            content: Text('These SKUs are not in your catalogue: $bad'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _downloadTemplate(List<SellerProduct> products) {
    final lines = ['sku,stock'];
    for (final p in products) {
      for (final v in p.variants) {
        lines.add('${v.sku},${v.stock}');
      }
    }
    ref.read(saveTextProvider)('clothsy-stock.csv', '${lines.join('\n')}\n');
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    return PanelPage(
      title: 'Inventory',
      subtitle:
          'Units available to sell. Ordered units are taken off as '
          'orders come in and come back when an order is cancelled.',
      onRefresh: () async => _refresh(),
      actions: [
        OutlinedButton.icon(
          onPressed: products.hasValue
              ? () => _downloadTemplate(products.value!)
              : null,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Download stock CSV'),
        ),
        FilledButton.icon(
          onPressed: _importing ? null : _import,
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: const Text('Import stock CSV'),
        ),
      ],
      children: [
        AsyncBody<List<SellerProduct>>(
          value: products,
          onRetry: () => ref.invalidate(productsProvider),
          builder: (all) {
            final rows = [
              for (final p in all)
                for (final v in p.variants)
                  if ((!_lowOnly || (v.isLowStock && v.isActive)) &&
                      (_query.isEmpty ||
                          '${v.sku} ${p.title} ${v.title}'
                              .toLowerCase()
                              .contains(_query)))
                    (p, v),
            ];
            final lowCount = [
              for (final p in all)
                for (final v in p.variants)
                  if (v.isLowStock && v.isActive) v,
            ].length;
            return PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Search SKU or product',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              setState(() => _query = v.trim().toLowerCase()),
                        ),
                      ),
                      FilterChip(
                        label: Text('Low stock ($lowCount)'),
                        selected: _lowOnly,
                        onSelected: (v) => setState(() => _lowOnly = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    EmptyStateView(
                      icon: Icons.inventory_2_outlined,
                      title: _lowOnly ? 'Nothing running low' : 'No sizes yet',
                      message: _lowOnly
                          ? 'Every size has more than its alert level.'
                          : 'Add sizes to your products to track their stock.',
                    )
                  else
                    ScrollTable(
                      columns: const [
                        DataColumn(label: Text('SKU')),
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('Size / colour')),
                        DataColumn(label: Text('Available'), numeric: true),
                        DataColumn(label: Text('Alert at'), numeric: true),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final (p, v) in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(v.sku)),
                              DataCell(
                                Text(
                                  p.title +
                                      (p.status == 'live'
                                          ? ''
                                          : ' (${productStatuses[p.status]})'),
                                ),
                              ),
                              DataCell(
                                Text(v.isActive ? v.title : '${v.title} (off)'),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (v.isLowStock && v.isActive)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 6),
                                        child: StatusChip(
                                          'Low',
                                          tone: Tone.warning,
                                        ),
                                      ),
                                    Text('${v.stock}'),
                                  ],
                                ),
                              ),
                              DataCell(Text('${v.lowStockThreshold}')),
                              DataCell(
                                TextButton(
                                  onPressed: () => _adjust(p, v),
                                  child: Text('Adjust ${v.sku}'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
        const _HistoryCard(),
      ],
    );
  }
}

class _AdjustDialog extends StatefulWidget {
  final SellerProduct product;
  final SellerVariant variant;

  const _AdjustDialog({required this.product, required this.variant});

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _form = GlobalKey<FormState>();
  final _units = TextEditingController();
  final _note = TextEditingController();
  bool _adding = true;

  @override
  void dispose() {
    _units.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    return AlertDialog(
      title: Text('Adjust ${v.sku}'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.product.title} · ${v.title} · ${v.stock} available',
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Add (restock)')),
                  ButtonSegment(value: false, label: Text('Remove')),
                ],
                selected: {_adding},
                onSelectionChanged: (s) => setState(() => _adding = s.first),
              ),
              const SizedBox(height: 12),
              FieldBox(
                label: 'Units',
                controller: _units,
                width: double.infinity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (s) {
                  final n = int.tryParse(s ?? '') ?? 0;
                  if (n <= 0) return 'How many units?';
                  if (!_adding && n > v.stock) {
                    return 'Only ${v.stock} available';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              FieldBox(
                label: 'Note (optional)',
                controller: _note,
                width: double.infinity,
                hint: _adding
                    ? 'New delivery from the workshop'
                    : 'Damaged in storage',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final n = int.parse(_units.text);
            Navigator.pop(context, (
              delta: _adding ? n : -n,
              note: _note.text.trim(),
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return PanelCard(
      title: 'Stock history',
      child: AsyncBody<List<StockMovement>>(
        value: ref.watch(stockHistoryProvider),
        onRetry: () => ref.invalidate(stockHistoryProvider),
        builder: (moves) => moves.isEmpty
            ? Text(
                'Every change to your stock is listed here.',
                style: AppTypography.body(color: colors.textSecondary),
              )
            : ScrollTable(
                columns: const [
                  DataColumn(label: Text('When')),
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Change'), numeric: true),
                  DataColumn(label: Text('Why')),
                ],
                rows: [
                  for (final m in moves)
                    DataRow(
                      cells: [
                        DataCell(Text(formatDateTime(m.createdAt))),
                        DataCell(Text('${m.sku} · ${m.productTitle}')),
                        DataCell(
                          Text(
                            m.delta > 0 ? '+${m.delta}' : '${m.delta}',
                            style: TextStyle(
                              color: m.delta > 0
                                  ? colors.success
                                  : colors.error,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            (stockReasons[m.reason] ?? m.reason) +
                                (m.note == null ? '' : ' — ${m.note}'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
