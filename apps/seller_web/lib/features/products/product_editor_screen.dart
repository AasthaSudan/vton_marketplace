import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/files.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../../data/seller_repository.dart';
import '../../widgets/panel_widgets.dart';
import 'products_screen.dart';

/// Shopper-app categories a listing can appear under.
const productCategories = {
  'dresses': 'Dresses',
  'tops': 'Tops',
  'outerwear': 'Outerwear',
  'shoes': 'Shoes',
  'bags': 'Bags',
};
const productAudiences = {'women': 'Women', 'men': 'Men'};

/// Adds a listing ([productId] null) or edits one (Blueprint fig. 33):
/// details, photos, sizes with price and stock, then submit for review.
class ProductEditorScreen extends ConsumerWidget {
  final String? productId;

  const ProductEditorScreen({super.key, this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (productId == null) return const _Editor(product: null);
    final product = ref.watch(productProvider(productId!));
    return AsyncBody<SellerProduct>(
      value: product,
      onRetry: () => ref.invalidate(productProvider(productId!)),
      builder: (p) => _Editor(key: ValueKey(p.updatedAt), product: p),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  final SellerProduct? product;

  const _Editor({super.key, required this.product});

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.product?.title);
  late final _description = TextEditingController(
    text: widget.product?.description,
  );
  late final _tags = TextEditingController(
    text: widget.product?.tags.join(', '),
  );
  late final _hsn = TextEditingController(text: widget.product?.hsnCode);
  late String? _category = productCategories.entries
      .where((e) => e.value == widget.product?.category)
      .map((e) => e.key)
      .firstOrNull;
  late final Set<String> _audiences = {
    ...?widget.product?.categoryHandles.where(productAudiences.containsKey),
  };
  late final List<String> _images = [...?widget.product?.images];
  late bool _tryOn = widget.product?.tryOnRequested ?? false;
  List<String> _missing = const [];
  bool _busy = false;
  bool _uploading = false;

  SellerProduct? get _p => widget.product;
  bool get _editable => _p == null || _p!.canEdit;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    _hsn.dispose();
    super.dispose();
  }

  ProductDraft get _draft => ProductDraft(
    title: _title.text.trim(),
    description: _description.text.trim(),
    category: productCategories[_category] ?? '',
    categoryHandles: [..._audiences, ?_category],
    tags: [
      for (final t in _tags.text.split(','))
        if (t.trim().isNotEmpty) t.trim().toLowerCase(),
    ],
    images: _images,
    tryOnRequested: _tryOn,
    hsnCode: _hsn.text.trim().isEmpty ? null : _hsn.text.trim(),
  );

  SellerRepository get _repo => ref.read(sellerRepositoryProvider);

  void _refresh() {
    ref.invalidate(productsProvider);
    ref.invalidate(dashboardProvider);
    if (_p != null) ref.invalidate(productProvider(_p!.id));
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on SellerFailure catch (e) {
      if (e.code == 'PRODUCT_INCOMPLETE') setState(() => _missing = e.missing);
      if (mounted) showFailure(context, e);
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await _guard(() async {
      if (_p == null) {
        final seller = ref.read(currentSellerProvider).requireValue!;
        final id = await _repo.createProduct(seller.sellerId, _draft);
        ref.invalidate(productsProvider);
        if (mounted) {
          showDone(context, 'Draft saved — now add its sizes');
          context.go('/products/$id');
        }
      } else {
        await _repo.updateProduct(_p!.id, _draft);
        _refresh();
        if (mounted) showDone(context, 'Saved');
      }
    });
  }

  Future<void> _submit() => _guard(() async {
    await _repo.updateProduct(_p!.id, _draft);
    await _repo.submitProduct(_p!.id);
    _refresh();
    if (mounted) showDone(context, 'Sent to Clothsy for review');
  });

  Future<void> _setListed(bool listed) => _guard(() async {
    await _repo.setListed(_p!.id, listed);
    _refresh();
    if (mounted) showDone(context, listed ? 'Back on sale' : 'Unpublished');
  });

  Future<void> _delete() async {
    final sure = await confirm(
      context,
      title: 'Delete this draft?',
      message: 'It has never been on sale, so it is removed for good.',
      confirmText: 'Delete',
      destructive: true,
    );
    if (!sure) return;
    await _guard(() async {
      await _repo.deleteProduct(_p!.id);
      ref.invalidate(productsProvider);
      if (mounted) context.go('/products');
    });
  }

  Future<void> _addImage() async {
    final file = await ref.read(pickFileProvider)([
      'jpg',
      'jpeg',
      'png',
      'webp',
    ]);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final seller = ref.read(currentSellerProvider).requireValue!;
      final url = await _repo.uploadImage(
        seller.sellerId,
        fileName: file.name,
        bytes: file.bytes,
        contentType: file.contentType,
      );
      setState(() => _images.add(url));
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editVariant([SellerVariant? v]) async {
    final draft = await showDialog<VariantDraft>(
      context: context,
      builder: (_) => VariantDialog(variant: v),
    );
    if (draft == null) return;
    await _guard(() async {
      if (v == null) {
        await _repo.addVariant(_p!.id, draft);
      } else {
        await _repo.updateVariant(v.id, draft);
      }
      _refresh();
    });
  }

  Future<void> _deleteVariant(SellerVariant v) => _guard(() async {
    await _repo.deleteVariant(v.id);
    _refresh();
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final p = _p;
    return PanelPage(
      title: p == null ? 'Add product' : p.title,
      subtitle: p == null ? 'Start with the details; sizes come next.' : null,
      actions: [
        TextButton.icon(
          onPressed: () => context.go('/products'),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('All products'),
        ),
        if (p != null)
          StatusChip(productStatuses[p.status]!, tone: productTone(p.status)),
      ],
      children: [
        if (p != null) _StatusNote(product: p),
        if (_missing.isNotEmpty)
          PanelCard(
            title: 'Needed before review',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _missing)
                  Chip(label: Text(missingLabels[m] ?? m)),
              ],
            ),
          ),
        Form(
          key: _form,
          child: PanelCard(
            title: 'Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FieldWrap(
                  children: [
                    FieldBox(
                      label: 'Title',
                      controller: _title,
                      enabled: _editable,
                      width: 520,
                      capitalization: TextCapitalization.words,
                      validator: (v) => (v ?? '').trim().length < 3
                          ? 'At least 3 characters'
                          : null,
                    ),
                    FieldBox(
                      label: 'Description',
                      controller: _description,
                      enabled: _editable,
                      width: 520,
                      maxLines: 5,
                      helper:
                          'Fabric, fit, care — what a shopper wants to know',
                    ),
                    SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final e in productCategories.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: _editable
                            ? (v) => setState(() => _category = v)
                            : null,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'For',
                          style: AppTypography.label(
                            color: colors.textSecondary,
                          ),
                        ),
                        for (final e in productAudiences.entries)
                          FilterChip(
                            label: Text(e.value),
                            selected: _audiences.contains(e.key),
                            onSelected: _editable
                                ? (on) => setState(
                                    () => on
                                        ? _audiences.add(e.key)
                                        : _audiences.remove(e.key),
                                  )
                                : null,
                          ),
                      ],
                    ),
                    FieldBox(
                      label: 'Search keywords',
                      controller: _tags,
                      enabled: _editable,
                      helper: 'Comma separated, e.g. linen, summer, office',
                    ),
                    FieldBox(
                      label: 'HSN code (for invoices)',
                      controller: _hsn,
                      enabled: _editable,
                      hint: '6206',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          (v ?? '').isEmpty ||
                              RegExp(r'^[0-9]{4,8}$').hasMatch(v!)
                          ? null
                          : '4 to 8 digits',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Photos',
                  style: AppTypography.h3(color: colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Portrait 3:4 on a plain background. The first photo is the '
                  'cover.',
                  style: AppTypography.caption(color: colors.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < _images.length; i++)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _images[i],
                              width: 90,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 90,
                                height: 120,
                                color: colors.surfaceMuted,
                              ),
                            ),
                          ),
                          if (_editable)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                tooltip: 'Remove photo ${i + 1}',
                                icon: const Icon(Icons.cancel, size: 20),
                                onPressed: () =>
                                    setState(() => _images.removeAt(i)),
                              ),
                            ),
                        ],
                      ),
                    if (_editable)
                      SizedBox(
                        width: 90,
                        height: 120,
                        child: OutlinedButton(
                          onPressed: _uploading ? null : _addImage,
                          child: _uploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_photo_alternate_outlined),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _tryOn,
                  onChanged: _editable
                      ? (v) => setState(() => _tryOn = v)
                      : null,
                  title: const Text('Ask for Clothsy AI Try-On'),
                  subtitle: Text(
                    p?.isTryOnEligible == true
                        ? 'Shoppers can try this on.'
                        : 'Clothsy checks your photos are Try-On ready when it '
                              'reviews the listing.',
                  ),
                ),
                if (_editable) ...[
                  const SizedBox(height: 8),
                  PrimaryButton(
                    text: p == null ? 'Save draft' : 'Save',
                    isFullWidth: false,
                    isLoading: _busy,
                    onPressed: _busy ? null : _save,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (p != null)
          PanelCard(
            title: 'Sizes, prices and stock',
            trailing: _editable
                ? TextButton.icon(
                    onPressed: _busy ? null : () => _editVariant(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add size'),
                  )
                : null,
            child: p.variants.isEmpty
                ? Text(
                    'Add each size (and colour) you sell, with its price and '
                    'stock.',
                    style: AppTypography.body(color: colors.textSecondary),
                  )
                : ScrollTable(
                    columns: const [
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Size / colour')),
                      DataColumn(label: Text('Price'), numeric: true),
                      DataColumn(label: Text('MRP'), numeric: true),
                      DataColumn(label: Text('Stock'), numeric: true),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final v in p.variants)
                        DataRow(
                          cells: [
                            DataCell(Text(v.sku)),
                            DataCell(
                              Text(v.isActive ? v.title : '${v.title} (off)'),
                            ),
                            DataCell(Text(CurrencyFormatter.format(v.price))),
                            DataCell(
                              Text(
                                v.compareAtPrice == null
                                    ? '—'
                                    : CurrencyFormatter.format(
                                        v.compareAtPrice!,
                                      ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${v.stock}',
                                style: v.isLowStock
                                    ? TextStyle(color: colors.warning)
                                    : null,
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_editable)
                                    IconButton(
                                      tooltip: 'Edit ${v.sku}',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      onPressed: () => _editVariant(v),
                                    ),
                                  if (p.canDelete)
                                    IconButton(
                                      tooltip: 'Remove ${v.sku}',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      onPressed: () => _deleteVariant(v),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        if (p != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (p.canSubmit)
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit for review'),
                ),
              if (p.status == 'live')
                OutlinedButton(
                  onPressed: _busy ? null : () => _setListed(false),
                  child: const Text('Unpublish'),
                ),
              if (p.status == 'archived')
                FilledButton(
                  onPressed: _busy ? null : () => _setListed(true),
                  child: Text(
                    p.approvedAt == null ? 'Back to draft' : 'Put back on sale',
                  ),
                ),
              if (p.canDelete)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  onPressed: _busy ? null : _delete,
                  child: const Text('Delete draft'),
                ),
            ],
          ),
      ],
    );
  }
}

class _StatusNote extends StatelessWidget {
  final SellerProduct product;

  const _StatusNote({required this.product});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (Color tone, String text) = switch (product.status) {
      'pending_review' => (
        colors.primary,
        'Clothsy is reviewing this listing (images, content, category, price, '
            'brand). It cannot be edited until the review is done.',
      ),
      'rejected' => (
        colors.warning,
        'Changes needed: ${product.rejectionReason ?? 'see Clothsy\'s note'}. '
            'Edit it and submit again.',
      ),
      'live' => (
        colors.success,
        'On sale. Changes you save show to shoppers straight away.',
      ),
      'archived' => (
        colors.textSecondary,
        'Unpublished — shoppers cannot see it.',
      ),
      _ => (
        colors.textSecondary,
        'Draft — add photos and sizes, then submit it for review.',
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTypography.bodyMedium(color: colors.textPrimary),
      ),
    );
  }
}

/// Adds or edits one size. Stock is set when a size is added; afterwards it
/// changes in Inventory (logged, safe while orders come in).
class VariantDialog extends StatefulWidget {
  final SellerVariant? variant;

  const VariantDialog({super.key, this.variant});

  @override
  State<VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<VariantDialog> {
  final _form = GlobalKey<FormState>();
  late final _sku = TextEditingController(text: widget.variant?.sku);
  late final _size = TextEditingController(text: widget.variant?.size);
  late final _colour = TextEditingController(text: widget.variant?.colorName);
  late final _hex = TextEditingController(text: widget.variant?.colorHex);
  late final _price = TextEditingController(
    text: widget.variant == null ? '' : _rupees(widget.variant!.price),
  );
  late final _mrp = TextEditingController(
    text: widget.variant?.compareAtPrice == null
        ? ''
        : _rupees(widget.variant!.compareAtPrice!),
  );
  late final _stock = TextEditingController(text: '0');
  late final _alert = TextEditingController(
    text: '${widget.variant?.lowStockThreshold ?? 3}',
  );
  late bool _active = widget.variant?.isActive ?? true;

  static String _rupees(int paise) =>
      paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);

  static int? _paise(String text) {
    final v = double.tryParse(text.trim());
    return v == null ? null : CurrencyFormatter.fromRupees(v);
  }

  @override
  void dispose() {
    for (final c in [
      _sku,
      _size,
      _colour,
      _hex,
      _price,
      _mrp,
      _stock,
      _alert,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.variant == null;
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(isNew ? 'Add a size' : 'Edit ${widget.variant!.sku}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: FieldWrap(
              children: [
                FieldBox(
                  label: 'SKU',
                  controller: _sku,
                  width: 200,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                FieldBox(
                  label: 'Size',
                  controller: _size,
                  width: 200,
                  hint: 'M, 32, Free size',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                FieldBox(
                  label: 'Colour (optional)',
                  controller: _colour,
                  width: 200,
                ),
                FieldBox(
                  label: 'Colour code (optional)',
                  controller: _hex,
                  width: 200,
                  hint: '#F4EFE6',
                  validator: (v) =>
                      (v ?? '').isEmpty ||
                          RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v!)
                      ? null
                      : 'Like #F4EFE6',
                ),
                FieldBox(
                  label: 'Selling price (₹)',
                  controller: _price,
                  width: 200,
                  inputFormatters: money,
                  validator: (v) =>
                      (_paise(v ?? '') ?? 0) <= 0 ? 'Required' : null,
                ),
                FieldBox(
                  label: 'MRP (₹, optional)',
                  controller: _mrp,
                  width: 200,
                  inputFormatters: money,
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    final mrp = _paise(v!);
                    final price = _paise(_price.text) ?? 0;
                    return mrp == null || mrp <= price
                        ? 'Above the price'
                        : null;
                  },
                ),
                if (isNew)
                  FieldBox(
                    label: 'Stock',
                    controller: _stock,
                    width: 200,
                    inputFormatters: digits,
                  ),
                FieldBox(
                  label: 'Low-stock alert at',
                  controller: _alert,
                  width: 200,
                  inputFormatters: digits,
                ),
                if (!isNew)
                  SizedBox(
                    width: 416,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                      title: const Text('On sale'),
                      subtitle: const Text('Stock changes in Inventory.'),
                    ),
                  ),
              ],
            ),
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
            Navigator.pop(
              context,
              VariantDraft(
                sku: _sku.text.trim(),
                size: _size.text.trim(),
                colorName: _colour.text.trim(),
                colorHex: _hex.text.trim().toUpperCase(),
                price: _paise(_price.text)!,
                compareAtPrice: _mrp.text.trim().isEmpty
                    ? null
                    : _paise(_mrp.text),
                stock: int.tryParse(_stock.text) ?? 0,
                lowStockThreshold: int.tryParse(_alert.text) ?? 3,
                isActive: _active,
              ),
            );
          },
          child: Text(isNew ? 'Add size' : 'Save size'),
        ),
      ],
    );
  }
}
