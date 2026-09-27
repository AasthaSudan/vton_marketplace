import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:clothsy_shop/core/theme/app_colors.dart';
import 'package:clothsy_shop/core/theme/app_radius.dart';
import 'package:clothsy_shop/core/theme/app_typography.dart';
import '../../domain/entities/tryon_session.dart';

class TryOnShimmerLoading extends StatefulWidget {
  final ProcessingStep? currentStep;
  final VoidCallback? onCancel;

  const TryOnShimmerLoading({super.key, this.currentStep, this.onCancel});

  @override
  State<TryOnShimmerLoading> createState() => _TryOnShimmerLoadingState();
}

class _TryOnShimmerLoadingState extends State<TryOnShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final step = widget.currentStep;
    final progress = step?.progress ?? 0.35;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, -0.8),
              end: Alignment(1.0 + 2.0 * _controller.value, 0.8),
              colors: [
                colors.surfaceMuted,
                colors.accentSoft.withOpacity(0.4),
                colors.surfaceMuted,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Subtle background grid watermark
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: CustomPaint(
                    painter: _SilhouetteGridPainter(color: colors.primary),
                  ),
                ),
              ),

              // Center Content Card
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rotating & Pulsing Atelier AI Orb
                      Transform.rotate(
                        angle: _controller.value * 2 * math.pi,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                colors.accent.withOpacity(0.8),
                                colors.primary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withOpacity(0.35),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Status Header
                      Text(
                        step?.title ?? 'Styling with Clothsy AI...',
                        textAlign: TextAlign.center,
                        style: AppTypography.h3(color: colors.textPrimary),
                      ),
                      const SizedBox(height: 8),

                      // Description
                      Text(
                        step?.description ??
                            'Harmonizing fabric drape, shadows & pose...',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ).copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 20),

                      // Progress Track
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: colors.border.withOpacity(0.4),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Estimated time
                      Text(
                        'Estimated time: ~${((1.0 - progress) * 4).ceil()}s',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ).copyWith(fontSize: 11),
                      ),

                      if (widget.onCancel != null) ...[
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: widget.onCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.buttonRadius,
                            ),
                          ),
                          child: const Text('Cancel Request'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SilhouetteGridPainter extends CustomPainter {
  final Color color;

  _SilhouetteGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
