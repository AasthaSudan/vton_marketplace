import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/seller_repository.dart';
import '../../widgets/panel_widgets.dart';

/// Brands sign in with email and password, or create an account to start
/// selling on Clothsy.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(sellerRepositoryProvider);
    try {
      if (_creating) {
        await repo.signUp(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
        );
      } else {
        await repo.signIn(email: _email.text, password: _password.text);
      }
      ref.read(signedInProvider.notifier).refresh();
    } on SellerFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surfaceMuted,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: PanelCard(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Clothsy',
                      style: AppTypography.h1(color: colors.primary),
                    ),
                    Text(
                      'Seller Panel',
                      style: AppTypography.label(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _creating ? 'Start selling on Clothsy' : 'Welcome back',
                      style: AppTypography.h2(color: colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _creating
                          ? 'Create your account, then tell us about your brand.'
                          : 'Sign in to run your store.',
                      style: AppTypography.body(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    if (_creating) ...[
                      FieldBox(
                        label: 'Your name',
                        controller: _name,
                        width: double.infinity,
                        capitalization: TextCapitalization.words,
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    FieldBox(
                      label: 'Email',
                      controller: _email,
                      width: double.infinity,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          RegExp(r'^\S+@\S+\.\S+$').hasMatch((v ?? '').trim())
                          ? null
                          : 'Enter a valid email',
                    ),
                    const SizedBox(height: 12),
                    FieldBox(
                      label: 'Password',
                      controller: _password,
                      width: double.infinity,
                      obscure: true,
                      helper: _creating ? 'At least 8 characters' : null,
                      validator: (v) => (v ?? '').length < (_creating ? 8 : 1)
                          ? (_creating
                                ? 'Use at least 8 characters'
                                : 'Enter your password')
                          : null,
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
                      text: _creating ? 'Create account' : 'Sign in',
                      isLoading: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _creating = !_creating;
                              _error = null;
                            }),
                      child: Text(
                        _creating
                            ? 'Already selling on Clothsy? Sign in'
                            : 'New brand? Create an account',
                      ),
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
