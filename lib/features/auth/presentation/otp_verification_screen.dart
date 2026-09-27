import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/buttons/clothsy_icon_button.dart';
import '../../../shared/widgets/buttons/pressable_scale.dart';
import '../../../shared/widgets/buttons/primary_button.dart';
import '../../../shared/widgets/feedback/clothsy_snackbar.dart';
import '../../../shared/widgets/inputs/clothsy_otp_field.dart';
import 'providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String? redirectPath;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.redirectPath,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  String _enteredOtp = '';
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_enteredOtp.length < 4) {
      ClothsySnackbar.show(
        context,
        message: 'Please enter the 4-digit code',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    final ok = await ref
        .read(authProvider.notifier)
        .verifyOtp(widget.phoneNumber, _enteredOtp);
    setState(() => _isLoading = false);

    if (ok && mounted) {
      ClothsySnackbar.show(
        context,
        message: 'Welcome to Clothsy!',
        type: SnackbarType.success,
      );
      if (widget.redirectPath != null && widget.redirectPath!.isNotEmpty) {
        context.go(widget.redirectPath!);
      } else {
        context.go('/');
      }
    }
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
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: colors.primary,
            ),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 32,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify Your Mobile',
                style: AppTypography.h1(color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'We have dispatched an SMS verification code to',
                style: AppTypography.caption(color: colors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.phoneNumber,
                    style: AppTypography.bodyMedium(weight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  PressableScale(
                    onTap: () => context.pop(),
                    child: Text(
                      'Edit',
                      style: AppTypography.caption(
                        color: colors.primary,
                        weight: FontWeight.w700,
                      ).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // OTP Boxes
              ClothsyOtpField(
                length: 4,
                onChanged: (val) => _enteredOtp = val,
                onCompleted: (val) {
                  _enteredOtp = val;
                  _verifyOtp();
                },
              ),
              const SizedBox(height: 32),

              // Verify Button
              PrimaryButton(
                text: 'Verify & Continue',
                isLoading: _isLoading,
                onPressed: _verifyOtp,
              ),
              const SizedBox(height: 24),

              // Resend Timer
              if (_secondsRemaining > 0)
                Text(
                  'Resend code in $_secondsRemaining seconds',
                  style: AppTypography.caption(color: colors.textSecondary),
                )
              else
                PressableScale(
                  onTap: () {
                    _startTimer();
                    ClothsySnackbar.show(
                      context,
                      message:
                          'New verification code sent to ${widget.phoneNumber}',
                      type: SnackbarType.info,
                    );
                  },
                  child: Text(
                    'Resend Code',
                    style: AppTypography.bodyMedium(
                      color: colors.primary,
                      weight: FontWeight.w700,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
