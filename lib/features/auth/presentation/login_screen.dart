import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/buttons/clothsy_icon_button.dart';
import '../../../shared/widgets/buttons/pressable_scale.dart';
import '../../../shared/widgets/buttons/primary_button.dart';
import '../../../shared/widgets/buttons/secondary_button.dart';
import '../../../shared/widgets/feedback/clothsy_snackbar.dart';
import '../../../shared/widgets/inputs/clothsy_text_field.dart';
import 'providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? redirectPath;

  const LoginScreen({super.key, this.redirectPath});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isPhoneMode = true;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSuccessRedirect() {
    if (widget.redirectPath != null) {
      context.go(widget.redirectPath!);
    } else {
      context.go('/');
    }
  }

  Future<void> _handlePhoneSubmit() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      ClothsySnackbar.show(
        context,
        message: 'Please enter a valid 10-digit mobile number',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    final ok = await ref.read(authProvider.notifier).sendPhoneOtp(phone);
    setState(() => _isLoading = false);

    if (ok && mounted) {
      context.push('/otp?phone=$phone&redirect=${widget.redirectPath ?? "/"}');
    }
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      ClothsySnackbar.show(context, message: 'Please enter a valid email address', type: SnackbarType.error);
      return;
    }
    if (password.length < 6) {
      ClothsySnackbar.show(context, message: 'Password must be at least 6 characters', type: SnackbarType.error);
      return;
    }

    setState(() => _isLoading = true);
    final ok = await ref.read(authProvider.notifier).signInWithEmail(email, password);
    setState(() => _isLoading = false);

    if (ok && mounted) {
      _onSuccessRedirect();
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final ok = await ref.read(authProvider.notifier).signInWithGoogle();
    setState(() => _isLoading = false);
    if (ok && mounted) _onSuccessRedirect();
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    final ok = await ref.read(authProvider.notifier).signInWithApple();
    setState(() => _isLoading = false);
    if (ok && mounted) _onSuccessRedirect();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ClothsyIconButton(
            size: 38,
            icon: Icon(Icons.close_rounded, size: 18, color: colors.primary),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            // Brand Logo & Headline
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.accentSoft, width: 1.5),
                ),
                child: Icon(Icons.auto_awesome, color: colors.primary, size: 28),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to Clothsy',
              textAlign: TextAlign.center,
              style: AppTypography.h1(color: colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to access your atelier orders, save wishlist pieces, and personalize your virtual try-on.',
              textAlign: TextAlign.center,
              style: AppTypography.body(color: colors.textSecondary),
            ),
            const SizedBox(height: 28),

            // Tab Switcher (Phone OTP / Email)
            Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PressableScale(
                      onTap: () => setState(() => _isPhoneMode = true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isPhoneMode ? colors.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: _isPhoneMode
                              ? [
                                  BoxShadow(
                                    color: colors.primary.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Phone OTP',
                          style: AppTypography.bodyMedium(
                            color: _isPhoneMode ? colors.primary : colors.textSecondary,
                            weight: _isPhoneMode ? FontWeight.w700 : FontWeight.w500,
                          ).copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PressableScale(
                      onTap: () => setState(() => _isPhoneMode = false),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_isPhoneMode ? colors.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: !_isPhoneMode
                              ? [
                                  BoxShadow(
                                    color: colors.primary.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Email & Password',
                          style: AppTypography.bodyMedium(
                            color: !_isPhoneMode ? colors.primary : colors.textSecondary,
                            weight: !_isPhoneMode ? FontWeight.w700 : FontWeight.w500,
                          ).copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form inputs
            if (_isPhoneMode) ...[
              ClothsyTextField(
                label: 'Mobile Number',
                hint: '98765 43210',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🇮🇳 +91',
                      style: AppTypography.bodyMedium(weight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(height: 20, width: 1, color: colors.border),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'Send Verification Code',
                isLoading: _isLoading,
                onPressed: _handlePhoneSubmit,
              ),
            ] else ...[
              ClothsyTextField(
                label: 'Email Address',
                hint: 'name@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
              ),
              const SizedBox(height: 16),
              ClothsyTextField(
                label: 'Password',
                hint: '••••••••',
                controller: _passwordController,
                isPassword: true,
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'Sign In',
                isLoading: _isLoading,
                onPressed: _handleEmailSubmit,
              ),
            ],
            const SizedBox(height: 28),

            // Divider "Or continue with"
            Row(
              children: [
                Expanded(child: Divider(color: colors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: AppTypography.caption(color: colors.textSecondary)),
                ),
                Expanded(child: Divider(color: colors.border)),
              ],
            ),
            const SizedBox(height: 24),

            // Social Buttons (Google and Apple)
            SecondaryButton(
              text: 'Continue with Google',
              icon: Icon(Icons.g_mobiledata_rounded, size: 26, color: colors.primary),
              onPressed: _handleGoogleSignIn,
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              text: 'Continue with Apple',
              icon: Icon(Icons.apple, size: 22, color: colors.primary),
              onPressed: _handleAppleSignIn,
            ),
            const SizedBox(height: 24),

            // Guest Browsing bypass
            Center(
              child: PressableScale(
                onTap: () {
                  ref.read(authProvider.notifier).continueAsGuest();
                  _onSuccessRedirect();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Continue as Guest',
                    style: AppTypography.bodyMedium(
                      color: colors.textSecondary,
                      weight: FontWeight.w600,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
