import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/seller_repository.dart';
import '../../widgets/panel_widgets.dart';

/// Step 1 of selling on Clothsy: name the brand (Blueprint fig. 31).
class RegisterBrandScreen extends ConsumerStatefulWidget {
  const RegisterBrandScreen({super.key});

  @override
  ConsumerState<RegisterBrandScreen> createState() =>
      _RegisterBrandScreenState();
}

class _RegisterBrandScreenState extends ConsumerState<RegisterBrandScreen> {
  final _form = GlobalKey<FormState>();
  final _brand = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _brand.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sellerRepositoryProvider)
          .registerSeller(_brand.text.trim());
      ref.invalidate(currentSellerProvider);
    } on SellerFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const steps = [
      'Apply',
      'Verify',
      'Set up your store',
      'Add products',
      'Approval',
      'Orders',
      'Payouts',
    ];
    return Scaffold(
      backgroundColor: colors.surfaceMuted,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: PanelCard(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sell on Clothsy',
                      style: AppTypography.h1(color: colors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tell us your brand's name. Next we verify your business "
                      'so every brand on Clothsy is genuine and ready to sell '
                      'from day one.',
                      style: AppTypography.body(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          StatusChip(
                            '${i + 1}. ${steps[i]}',
                            tone: i == 0 ? Tone.info : Tone.neutral,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FieldBox(
                      label: 'Brand name',
                      controller: _brand,
                      width: double.infinity,
                      capitalization: TextCapitalization.words,
                      validator: (v) {
                        final n = (v ?? '').trim().length;
                        return n < 2 || n > 60 ? '2 to 60 characters' : null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: AppTypography.bodyMedium(color: colors.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      text: 'Start my application',
                      isLoading: _busy,
                      onPressed: _busy ? null : _register,
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(sellerRepositoryProvider).signOut();
                        ref.read(signedInProvider.notifier).refresh();
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
