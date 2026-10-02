import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files.dart';
import '../../core/indian_states.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../../data/seller_repository.dart';
import '../../widgets/panel_widgets.dart';

/// The verification application (Blueprint fig. 32): owner and business,
/// tax, pickup address, payout account and documents, then submit. After
/// approval the same screen shows the business details ([embedded]).
class ApplicationScreen extends ConsumerWidget {
  final bool embedded;

  const ApplicationScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(currentSellerProvider).value;
    final application = ref.watch(applicationProvider);
    final page = seller == null
        ? const SizedBox.shrink()
        : AsyncBody<SellerApplication>(
            value: application,
            onRetry: () => ref.invalidate(applicationProvider),
            builder: (app) => _ApplicationPage(
              seller: seller,
              application: app,
              embedded: embedded,
            ),
          );
    if (embedded) return page;
    return Scaffold(
      backgroundColor: context.colors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: Text(
          'Clothsy Seller Panel',
          style: AppTypography.h3(color: context.colors.primary),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(sellerRepositoryProvider).signOut();
              ref.read(signedInProvider.notifier).refresh();
            },
            child: const Text('Sign out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: page,
    );
  }
}

class _ApplicationPage extends ConsumerWidget {
  final SellerContext seller;
  final SellerApplication application;
  final bool embedded;

  const _ApplicationPage({
    required this.seller,
    required this.application,
    required this.embedded,
  });

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(currentSellerProvider);
    ref.invalidate(applicationProvider);
    ref.invalidate(bankAccountProvider);
    ref.invalidate(documentsProvider);
    ref.invalidate(applicationHistoryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = application.isEditable && seller.canManage;
    return PanelPage(
      title: embedded ? 'Business details' : seller.name,
      subtitle: embedded
          ? 'What Clothsy verified about your business.'
          : 'Verification application',
      onRefresh: () => _refresh(ref),
      children: [
        _StatusBanner(seller: seller, application: application),
        if (editable && seller.missing.isNotEmpty)
          _MissingList(missing: seller.missing),
        _BusinessForm(
          key: ValueKey(application.submittedAt ?? application.status),
          seller: seller,
          application: application,
          editable: editable,
        ),
        _BankCard(seller: seller, application: application),
        _DocumentsCard(
          seller: seller,
          application: application,
          editable: editable,
        ),
        if (editable)
          _SubmitCard(seller: seller, onSubmitted: () => _refresh(ref)),
        const _HistoryCard(),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final SellerContext seller;
  final SellerApplication application;

  const _StatusBanner({required this.seller, required this.application});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (
      Color tone,
      IconData icon,
      String title,
      String body,
    ) = switch (application.status) {
      'submitted' => (
        colors.primary,
        Icons.hourglass_top_rounded,
        'Clothsy is reviewing your application',
        'Our verification team checks every brand, usually within 2 '
            'working days. We will let you know here.',
      ),
      'needs_info' => (
        colors.warning,
        Icons.edit_note_rounded,
        'A little more information is needed',
        application.reviewNote ?? 'Update the details below and submit again.',
      ),
      'rejected' => (
        colors.error,
        Icons.block_rounded,
        'Your application was not approved',
        application.reviewNote ?? 'Contact Clothsy support to know more.',
      ),
      'approved' => (
        colors.success,
        Icons.verified_rounded,
        'Verified',
        'Your store is approved. Business details are locked; contact '
            'Clothsy support to change them.',
      ),
      _ => (
        colors.primary,
        Icons.assignment_outlined,
        'Complete your application',
        'Fill in each section, upload your documents and submit. Your '
            'progress is saved as you go.',
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h3(color: tone)),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.body(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingList extends StatelessWidget {
  final List<String> missing;

  const _MissingList({required this.missing});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PanelCard(
      title: 'Still needed before you can submit',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final m in missing)
            Chip(
              avatar: Icon(
                Icons.radio_button_unchecked,
                size: 16,
                color: colors.warning,
              ),
              label: Text(missingLabels[m] ?? m),
            ),
        ],
      ),
    );
  }
}

class _BusinessForm extends ConsumerStatefulWidget {
  final SellerContext seller;
  final SellerApplication application;
  final bool editable;

  const _BusinessForm({
    super.key,
    required this.seller,
    required this.application,
    required this.editable,
  });

  @override
  ConsumerState<_BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends ConsumerState<_BusinessForm> {
  final _form = GlobalKey<FormState>();
  late final _owner = TextEditingController(text: widget.application.ownerName);
  late final _email = TextEditingController(
    text: widget.application.contactEmail,
  );
  late final _phone = TextEditingController(
    text: widget.application.contactPhone,
  );
  late final _legal = TextEditingController(text: widget.application.legalName);
  late final _pan = TextEditingController(text: widget.application.pan ?? '');
  late final _gstin = TextEditingController(
    text: widget.application.gstin ?? '',
  );
  late final _line1 = TextEditingController(
    text: widget.application.pickupLine1,
  );
  late final _line2 = TextEditingController(
    text: widget.application.pickupLine2,
  );
  late final _city = TextEditingController(text: widget.application.pickupCity);
  late final _pin = TextEditingController(
    text: widget.application.pickupPinCode ?? '',
  );
  late String? _type = widget.application.businessType;
  late String? _state = widget.application.pickupState.isEmpty
      ? null
      : widget.application.pickupState;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _owner,
      _email,
      _phone,
      _legal,
      _pan,
      _gstin,
      _line1,
      _line2,
      _city,
      _pin,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optional(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(sellerRepositoryProvider)
          .saveApplication(
            widget.seller.sellerId,
            SellerApplication(
              status: widget.application.status,
              ownerName: _owner.text.trim(),
              contactEmail: _email.text.trim(),
              contactPhone: _phone.text.trim(),
              businessType: _type,
              legalName: _legal.text.trim(),
              pan: _optional(_pan.text),
              gstin: _optional(_gstin.text),
              pickupLine1: _line1.text.trim(),
              pickupLine2: _line2.text.trim(),
              pickupCity: _city.text.trim(),
              pickupState: _state ?? '',
              pickupPinCode: _optional(_pin.text),
            ),
          );
      ref.invalidate(currentSellerProvider);
      ref.invalidate(applicationProvider);
      if (mounted) showDone(context, 'Saved');
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.editable;
    final upper = [UpperCaseTextFormatter()];
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelCard(
            title: 'Owner and business',
            child: FieldWrap(
              children: [
                FieldBox(
                  label: "Owner's full name",
                  controller: _owner,
                  enabled: enabled,
                  capitalization: TextCapitalization.words,
                ),
                FieldBox(
                  label: 'Contact email',
                  controller: _email,
                  enabled: enabled,
                  keyboardType: TextInputType.emailAddress,
                ),
                FieldBox(
                  label: 'Contact phone',
                  controller: _phone,
                  enabled: enabled,
                  hint: '+919876543210',
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v ?? '').isEmpty ||
                          RegExp(r'^\+91[6-9]\d{9}$').hasMatch(v!.trim())
                      ? null
                      : 'Use +91 and the 10-digit number',
                ),
                SizedBox(
                  width: 340,
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Type of business',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final e in businessTypes.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: enabled
                        ? (v) => setState(() => _type = v)
                        : null,
                  ),
                ),
                FieldBox(
                  label: 'Legal business name',
                  controller: _legal,
                  enabled: enabled,
                  helper: 'As on your PAN or GST certificate',
                ),
              ],
            ),
          ),
          PanelCard(
            title: 'Tax and identity',
            child: FieldWrap(
              children: [
                FieldBox(
                  label: 'PAN',
                  controller: _pan,
                  enabled: enabled,
                  hint: 'ABCDE1234F',
                  inputFormatters: upper,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ||
                          RegExp(
                            r'^[A-Z]{5}[0-9]{4}[A-Z]$',
                          ).hasMatch(v!.trim().toUpperCase())
                      ? null
                      : 'A PAN looks like ABCDE1234F',
                ),
                FieldBox(
                  label: 'GSTIN (if registered)',
                  controller: _gstin,
                  enabled: enabled,
                  hint: '07ABCDE1234F1Z5',
                  inputFormatters: upper,
                  helper: 'Needed for tax invoices; it contains your PAN',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ||
                          RegExp(
                            r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
                          ).hasMatch(v!.trim().toUpperCase())
                      ? null
                      : 'A GSTIN has 15 characters, e.g. 07ABCDE1234F1Z5',
                ),
              ],
            ),
          ),
          PanelCard(
            title: 'Pickup address',
            child: FieldWrap(
              children: [
                FieldBox(
                  label: 'Address line 1',
                  controller: _line1,
                  enabled: enabled,
                  width: 520,
                ),
                FieldBox(
                  label: 'Address line 2 (optional)',
                  controller: _line2,
                  enabled: enabled,
                  width: 520,
                ),
                FieldBox(label: 'City', controller: _city, enabled: enabled),
                SizedBox(
                  width: 340,
                  child: DropdownButtonFormField<String>(
                    initialValue: indianStates.contains(_state) ? _state : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final s in indianStates)
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: enabled
                        ? (v) => setState(() => _state = v)
                        : null,
                  ),
                ),
                FieldBox(
                  label: 'PIN code',
                  controller: _pin,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (v) =>
                      (v ?? '').isEmpty ||
                          RegExp(r'^[1-9][0-9]{5}$').hasMatch(v!)
                      ? null
                      : '6 digits',
                ),
              ],
            ),
          ),
          if (enabled)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PrimaryButton(
                  text: 'Save details',
                  isFullWidth: false,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class _BankCard extends ConsumerStatefulWidget {
  final SellerContext seller;
  final SellerApplication application;

  const _BankCard({required this.seller, required this.application});

  @override
  ConsumerState<_BankCard> createState() => _BankCardState();
}

class _BankCardState extends ConsumerState<_BankCard> {
  final _form = GlobalKey<FormState>();
  final _holder = TextEditingController();
  final _number = TextEditingController();
  final _confirm = TextEditingController();
  final _ifsc = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _holder.dispose();
    _number.dispose();
    _confirm.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(sellerRepositoryProvider)
          .setBankAccount(
            widget.seller.sellerId,
            accountHolder: _holder.text.trim(),
            accountNumber: _number.text.trim(),
            ifsc: _ifsc.text.trim(),
          );
      ref.invalidate(bankAccountProvider);
      ref.invalidate(currentSellerProvider);
      if (mounted) {
        setState(() => _editing = false);
        showDone(context, 'Payout account saved');
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final account = ref.watch(bankAccountProvider);
    final status = widget.application.status;
    final canChange =
        widget.seller.isOwner && status != 'submitted' && status != 'rejected';
    return PanelCard(
      title: 'Payout account',
      trailing: canChange && !_editing
          ? TextButton(
              onPressed: () => setState(() => _editing = true),
              child: Text(account.value == null ? 'Add' : 'Change'),
            )
          : null,
      child: _editing
          ? Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status == 'approved')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'A new account pauses payouts until Clothsy verifies it.',
                        style: AppTypography.bodyMedium(color: colors.warning),
                      ),
                    ),
                  FieldWrap(
                    children: [
                      FieldBox(
                        label: 'Account holder name',
                        controller: _holder,
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'As printed on the cheque'
                            : null,
                      ),
                      FieldBox(
                        label: 'Account number',
                        controller: _number,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) =>
                            RegExp(r'^[0-9]{9,18}$').hasMatch(v ?? '')
                            ? null
                            : '9 to 18 digits',
                      ),
                      FieldBox(
                        label: 'Confirm account number',
                        controller: _confirm,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) =>
                            v == _number.text ? null : 'Numbers do not match',
                      ),
                      FieldBox(
                        label: 'IFSC',
                        controller: _ifsc,
                        hint: 'HDFC0001234',
                        inputFormatters: [UpperCaseTextFormatter()],
                        validator: (v) =>
                            RegExp(
                              r'^[A-Z]{4}0[A-Z0-9]{6}$',
                            ).hasMatch((v ?? '').trim().toUpperCase())
                            ? null
                            : '11 characters, e.g. HDFC0001234',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: const Text('Save account'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _editing = false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : AsyncBody<BankAccount?>(
              value: account,
              onRetry: () => ref.invalidate(bankAccountProvider),
              builder: (b) => b == null
                  ? Text(
                      'Add the bank account Clothsy pays you into. Upload a '
                      'cancelled cheque for it below.',
                      style: AppTypography.body(color: colors.textSecondary),
                    )
                  : Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${b.accountHolder} · ••••${b.last4} · ${b.ifsc}',
                          style: AppTypography.bodyMedium(
                            color: colors.textPrimary,
                          ),
                        ),
                        StatusChip(
                          switch (b.status) {
                            'verified' => 'Verified',
                            'failed' => 'Could not verify',
                            _ => 'Not verified yet',
                          },
                          tone: switch (b.status) {
                            'verified' => Tone.success,
                            'failed' => Tone.danger,
                            _ => Tone.warning,
                          },
                        ),
                      ],
                    ),
            ),
    );
  }
}

class _DocumentsCard extends ConsumerStatefulWidget {
  final SellerContext seller;
  final SellerApplication application;
  final bool editable;

  const _DocumentsCard({
    required this.seller,
    required this.application,
    required this.editable,
  });

  @override
  ConsumerState<_DocumentsCard> createState() => _DocumentsCardState();
}

class _DocumentsCardState extends ConsumerState<_DocumentsCard> {
  String? _uploading;

  Future<void> _upload(String kind) async {
    final file = await ref.read(pickFileProvider)([
      'pdf',
      'jpg',
      'jpeg',
      'png',
    ]);
    if (file == null) return;
    setState(() => _uploading = kind);
    try {
      await ref
          .read(sellerRepositoryProvider)
          .uploadDocument(
            widget.seller.sellerId,
            kind: kind,
            fileName: file.name,
            bytes: file.bytes,
            contentType: file.contentType,
          );
      ref.invalidate(documentsProvider);
      ref.invalidate(currentSellerProvider);
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _remove(SellerDocument doc) async {
    try {
      await ref.read(sellerRepositoryProvider).deleteDocument(doc);
      ref.invalidate(documentsProvider);
      ref.invalidate(currentSellerProvider);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final needsGst = (widget.application.gstin ?? '').isNotEmpty;
    final kinds = [
      'pan_card',
      'cancelled_cheque',
      if (needsGst) 'gst_certificate',
      'address_proof',
      'brand_authorisation',
    ];
    return PanelCard(
      title: 'Documents',
      child: AsyncBody<List<SellerDocument>>(
        value: ref.watch(documentsProvider),
        onRetry: () => ref.invalidate(documentsProvider),
        builder: (docs) => Column(
          children: [
            for (final kind in kinds)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      docs.any((d) => d.kind == kind)
                          ? Icons.check_circle_rounded
                          : Icons.description_outlined,
                      color: docs.any((d) => d.kind == kind)
                          ? colors.success
                          : colors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            documentKinds[kind]! +
                                (kind == 'address_proof' ||
                                        kind == 'brand_authorisation'
                                    ? ' (optional)'
                                    : ''),
                            style: AppTypography.bodyMedium(
                              color: colors.textPrimary,
                            ),
                          ),
                          for (final d in docs.where((d) => d.kind == kind))
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    d.fileName,
                                    style: AppTypography.caption(
                                      color: colors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.editable)
                                  IconButton(
                                    tooltip: 'Remove ${d.fileName}',
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () => _remove(d),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (widget.editable)
                      _uploading == kind
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton.icon(
                              onPressed: _uploading == null
                                  ? () => _upload(kind)
                                  : null,
                              icon: const Icon(Icons.upload_rounded, size: 18),
                              label: const Text('Upload'),
                            ),
                  ],
                ),
              ),
            if (widget.editable)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PDF, JPG or PNG, up to 10 MB. Only you and Clothsy '
                  'verification can open these.',
                  style: AppTypography.caption(color: colors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubmitCard extends ConsumerStatefulWidget {
  final SellerContext seller;
  final Future<void> Function() onSubmitted;

  const _SubmitCard({required this.seller, required this.onSubmitted});

  @override
  ConsumerState<_SubmitCard> createState() => _SubmitCardState();
}

class _SubmitCardState extends ConsumerState<_SubmitCard> {
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(sellerRepositoryProvider)
          .submitApplication(widget.seller.sellerId);
      await widget.onSubmitted();
      if (mounted) showDone(context, 'Sent to Clothsy for review');
    } catch (e) {
      if (mounted) showFailure(context, e);
      ref.invalidate(currentSellerProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.seller.missing.isEmpty;
    return PanelCard(
      title: 'Submit for verification',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ready
                ? 'Everything is in. Clothsy will review your details and '
                      'documents.'
                : 'Complete the items listed above to submit.',
            style: AppTypography.body(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            text: 'Submit application',
            isFullWidth: false,
            isLoading: _busy,
            onPressed: ready && !_busy ? _submit : null,
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard();

  static const _labels = {
    'draft': 'Application started',
    'submitted': 'Submitted for review',
    'needs_info': 'More information requested',
    'approved': 'Approved',
    'rejected': 'Not approved',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final history = ref.watch(applicationHistoryProvider).value ?? const [];
    if (history.isEmpty) return const SizedBox.shrink();
    return PanelCard(
      title: 'Verification history',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in history.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      formatDateTime(e.createdAt),
                      style: AppTypography.caption(color: colors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _labels[e.toStatus]! +
                          (e.note == null ? '' : ' — ${e.note}'),
                      style: AppTypography.bodyMedium(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
