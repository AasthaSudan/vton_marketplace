import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/primary_button.dart';

class ErrorStateView extends StatelessWidget {
  final String title;
  final String message;
  final String retryText;
  final VoidCallback? onRetry;
  final Widget? illustration;

  const ErrorStateView({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'We could not load the information. Please check your connection and try again.',
    this.retryText = 'Try Again',
    this.onRetry,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (illustration != null)
              illustration!
            else
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 40,
                  color: colors.error,
                ),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h2(color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body(color: colors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 28),
              PrimaryButton(
                text: retryText,
                onPressed: onRetry,
                isFullWidth: false,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
