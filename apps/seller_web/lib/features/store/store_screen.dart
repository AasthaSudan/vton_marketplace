import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/panel_widgets.dart';

/// The brand's storefront and collections (Blueprint fig. 30, Store).
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storefront = ref.watch(storefrontProvider);
    return PanelPage(
      title: 'Store',
      subtitle: 'How your brand looks to shoppers on Clothsy.',
      onRefresh: () async {
        ref.invalidate(storefrontProvider);
        ref.invalidate(collectionsProvider);
      },
      children: [
        AsyncBody<Storefront>(
          value: storefront,
          onRetry: () => ref.invalidate(storefrontProvider),
          builder: (s) => _StorefrontForm(storefront: s),
        ),
        const _CollectionsCard(),
      ],
    );
  }
}

class _StorefrontForm extends ConsumerStatefulWidget {
  final Storefront storefront;

  const _StorefrontForm({required this.storefront});

  @override
  ConsumerState<_StorefrontForm> createState() => _StorefrontFormState();
}

class _StorefrontFormState extends ConsumerState<_StorefrontForm> {
  final _form = GlobalKey<FormState>();
  late final s = widget.storefront;
  late final _name = TextEditingController(text: s.name);
  late final _tagline = TextEditingController(text: s.tagline);
  late final _story = TextEditingController(text: s.story);
  late final _city = TextEditingController(text: s.city);
  late final _instagram = TextEditingController(text: s.instagramUrl);
  late final _website = TextEditingController(text: s.websiteUrl);
  late final _email = TextEditingController(text: s.supportEmail);
  late final _dispatch = TextEditingController(text: '${s.dispatchDays}');
  late final _returns = TextEditingController(text: '${s.returnWindowDays}');
  late final _returnPolicy = TextEditingController(text: s.returnPolicy);
  late final _shippingPolicy = TextEditingController(text: s.shippingPolicy);
  late String? _logo = s.logoUrl;
  late String? _banner = s.bannerUrl;
  String? _uploading;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _tagline,
      _story,
      _city,
      _instagram,
      _website,
      _email,
      _dispatch,
      _returns,
      _returnPolicy,
      _shippingPolicy,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  String? _url(String? v) =>
      (v ?? '').trim().isEmpty ||
          RegExp(r'^https://\S+\.\S+').hasMatch(v!.trim())
      ? null
      : 'Starts with https://';

  Future<void> _upload(String which) async {
    final file = await ref.read(pickFileProvider)([
      'jpg',
      'jpeg',
      'png',
      'webp',
    ]);
    if (file == null) return;
    setState(() => _uploading = which);
    try {
      final seller = ref.read(currentSellerProvider).requireValue!;
      final url = await ref
          .read(sellerRepositoryProvider)
          .uploadImage(
            seller.sellerId,
            fileName: file.name,
            bytes: file.bytes,
            contentType: file.contentType,
          );
      setState(() => which == 'logo' ? _logo = url : _banner = url);
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final seller = ref.read(currentSellerProvider).requireValue!;
      await ref
          .read(sellerRepositoryProvider)
          .saveStorefront(
            seller.sellerId,
            Storefront(
              name: _name.text.trim(),
              tagline: _tagline.text.trim(),
              story: _story.text.trim(),
              logoUrl: _logo,
              bannerUrl: _banner,
              city: _city.text.trim(),
              dispatchDays: int.parse(_dispatch.text),
              returnWindowDays: int.parse(_returns.text),
              instagramUrl: _optional(_instagram),
              websiteUrl: _optional(_website),
              supportEmail: _optional(_email),
              returnPolicy: _returnPolicy.text.trim(),
              shippingPolicy: _shippingPolicy.text.trim(),
            ),
          );
      ref.invalidate(storefrontProvider);
      ref.invalidate(currentSellerProvider);
      if (mounted) showDone(context, 'Storefront saved');
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _image(String which, String? url, double w, double h) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          which == 'logo' ? 'Logo (square)' : 'Banner (wide)',
          style: AppTypography.label(color: colors.textSecondary),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _uploading == null ? () => _upload(which) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: _uploading == which
                ? const Center(child: CircularProgressIndicator())
                : url == null
                ? Center(
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      semanticLabel: 'Upload $which',
                      color: colors.textSecondary,
                    ),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelCard(
            title: 'Brand',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _image('logo', _logo, 120, 120),
                    _image('banner', _banner, 320, 120),
                  ],
                ),
                const SizedBox(height: 16),
                FieldWrap(
                  children: [
                    FieldBox(
                      label: 'Brand name',
                      controller: _name,
                      validator: (v) {
                        final n = (v ?? '').trim().length;
                        return n < 2 || n > 60 ? '2 to 60 characters' : null;
                      },
                    ),
                    FieldBox(
                      label: 'Tagline',
                      controller: _tagline,
                      hint: 'Handwoven linen from Jaipur',
                    ),
                    FieldBox(label: 'City', controller: _city),
                    FieldBox(
                      label: 'Brand story',
                      controller: _story,
                      width: 696,
                      maxLines: 5,
                      helper: 'Who you are, what you make and why',
                    ),
                    FieldBox(
                      label: 'Instagram (optional)',
                      controller: _instagram,
                      hint: 'https://instagram.com/yourbrand',
                      validator: _url,
                    ),
                    FieldBox(
                      label: 'Website (optional)',
                      controller: _website,
                      hint: 'https://',
                      validator: _url,
                    ),
                    FieldBox(
                      label: 'Customer support email (optional)',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ||
                              RegExp(r'^\S+@\S+\.\S+$').hasMatch(v!.trim())
                          ? null
                          : 'Enter a valid email',
                    ),
                  ],
                ),
              ],
            ),
          ),
          PanelCard(
            title: 'Shipping and returns',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FieldWrap(
                  children: [
                    FieldBox(
                      label: 'Dispatch within (days)',
                      controller: _dispatch,
                      width: 200,
                      inputFormatters: digits,
                      helper:
                          'Shown on product pages; late dispatch '
                          'lowers your score',
                      validator: (v) {
                        final n = int.tryParse(v ?? '') ?? 0;
                        return n < 1 || n > 30 ? '1 to 30' : null;
                      },
                    ),
                    FieldBox(
                      label: 'Return window (days)',
                      controller: _returns,
                      width: 200,
                      inputFormatters: digits,
                      helper: 'Payouts follow when it closes',
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n > 60 ? '0 to 60' : null;
                      },
                    ),
                    FieldBox(
                      label: 'Return policy',
                      controller: _returnPolicy,
                      width: 696,
                      maxLines: 3,
                    ),
                    FieldBox(
                      label: 'Shipping policy',
                      controller: _shippingPolicy,
                      width: 696,
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Save storefront',
                  isFullWidth: false,
                  isLoading: _saving,
                  onPressed: _saving || _uploading != null ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionsCard extends ConsumerWidget {
  const _CollectionsCard();

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    SellerCollection? c,
  ]) async {
    final products = ref.read(productsProvider).value ?? const [];
    final result = await showDialog<_CollectionDraft>(
      context: context,
      builder: (_) => _CollectionDialog(collection: c, products: products),
    );
    if (result == null) return;
    try {
      final seller = ref.read(currentSellerProvider).requireValue!;
      await ref
          .read(sellerRepositoryProvider)
          .saveCollection(
            seller.sellerId,
            id: c?.id,
            title: result.title,
            description: result.description,
            productIds: result.productIds,
            isVisible: result.isVisible,
          );
      ref.invalidate(collectionsProvider);
      if (context.mounted) showDone(context, 'Collection saved');
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SellerCollection c,
  ) async {
    final sure = await confirm(
      context,
      title: 'Delete "${c.title}"?',
      message: 'The products stay in your store.',
      confirmText: 'Delete',
      destructive: true,
    );
    if (!sure) return;
    try {
      await ref.read(sellerRepositoryProvider).deleteCollection(c.id);
      ref.invalidate(collectionsProvider);
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    ref.watch(productsProvider);
    return PanelCard(
      title: 'Collections',
      trailing: TextButton.icon(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('New collection'),
      ),
      child: AsyncBody<List<SellerCollection>>(
        value: ref.watch(collectionsProvider),
        onRetry: () => ref.invalidate(collectionsProvider),
        builder: (list) => list.isEmpty
            ? Text(
                'Group products for your storefront, e.g. "Summer Linen" or '
                '"Festive Edit".',
                style: AppTypography.body(color: colors.textSecondary),
              )
            : Column(
                children: [
                  for (final c in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.title),
                      subtitle: Text(
                        '${c.productIds.length} product'
                        '${c.productIds.length == 1 ? '' : 's'}'
                        '${c.isVisible ? '' : ' · hidden'}',
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Edit ${c.title}',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(context, ref, c),
                          ),
                          IconButton(
                            tooltip: 'Delete ${c.title}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, ref, c),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CollectionDraft {
  final String title;
  final String description;
  final List<String> productIds;
  final bool isVisible;

  const _CollectionDraft(
    this.title,
    this.description,
    this.productIds,
    this.isVisible,
  );
}

class _CollectionDialog extends StatefulWidget {
  final SellerCollection? collection;
  final List<SellerProduct> products;

  const _CollectionDialog({this.collection, required this.products});

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.collection?.title);
  late final _description = TextEditingController(
    text: widget.collection?.description,
  );
  late final Set<String> _picked = {...?widget.collection?.productIds};
  late bool _visible = widget.collection?.isVisible ?? true;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.collection == null ? 'New collection' : 'Edit collection',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FieldBox(
                  label: 'Collection name',
                  controller: _title,
                  width: double.infinity,
                  validator: (v) {
                    final n = (v ?? '').trim().length;
                    return n < 1 || n > 60 ? '1 to 60 characters' : null;
                  },
                ),
                const SizedBox(height: 12),
                FieldBox(
                  label: 'Description (optional)',
                  controller: _description,
                  width: double.infinity,
                  maxLines: 2,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _visible,
                  onChanged: (v) => setState(() => _visible = v),
                  title: const Text('Show on my storefront'),
                ),
                const Divider(),
                if (widget.products.isEmpty)
                  const Text('Add products first, then group them here.')
                else
                  for (final p in widget.products)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _picked.contains(p.id),
                      onChanged: (on) => setState(
                        () => on == true
                            ? _picked.add(p.id)
                            : _picked.remove(p.id),
                      ),
                      title: Text(p.title),
                      subtitle: Text(productStatuses[p.status] ?? p.status),
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
              _CollectionDraft(_title.text.trim(), _description.text.trim(), [
                for (final p in widget.products)
                  if (_picked.contains(p.id)) p.id,
              ], _visible),
            );
          },
          child: const Text('Save collection'),
        ),
      ],
    );
  }
}
