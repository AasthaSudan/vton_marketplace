import 'package:flutter/material.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';

class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Design Tokens',
          style: AppTypography.h3(
            color: colors.textPrimary,
          ).copyWith(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        children: [
          // ── Colors ──────────────────────────────────────────────────
          _SectionLabel('Colors'),
          _Card(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ColorDot('Primary', colors.primary),
                _ColorDot('Accent', colors.accent),
                _ColorDot('Soft', colors.accentSoft),
                _ColorDot('Success', colors.success),
                _ColorDot('Error', colors.error),
                _ColorDot('Rating', colors.rating),
                _ColorDot('Muted', colors.surfaceMuted),
                _ColorDot('Surface', colors.surface),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Typography ───────────────────────────────────────────────
          _SectionLabel('Typography'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Display',
                  style: AppTypography.display().copyWith(fontSize: 32),
                ),
                const SizedBox(height: 4),
                Text('Headline 1', style: AppTypography.h1()),
                const SizedBox(height: 4),
                Text('Headline 2', style: AppTypography.h2()),
                const SizedBox(height: 4),
                Text('Headline 3', style: AppTypography.h3()),
                const SizedBox(height: 4),
                Text(
                  'Body — effortless drape and comfort',
                  style: AppTypography.body(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Caption — express shipping across India',
                  style: AppTypography.caption(),
                ),
                const SizedBox(height: 4),
                Text(
                  'LABEL — VIRTUAL TRY-ON READY',
                  style: AppTypography.label(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Buttons ──────────────────────────────────────────────────
          _SectionLabel('Buttons'),
          _Card(
            child: Column(
              children: [
                PrimaryButton(
                  text: 'Primary Button',
                  onPressed: () => ClothsySnackbar.show(
                    context,
                    message: 'Primary tapped',
                    type: SnackbarType.success,
                  ),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  text: 'Loading State',
                  isLoading: true,
                  onPressed: () {},
                ),
                const SizedBox(height: 10),
                const PrimaryButton(text: 'Disabled', onPressed: null),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Radius ───────────────────────────────────────────────────
          _SectionLabel('Radius & Elevation'),
          _Card(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _RadiusSwatch('sm', 8, colors),
                _RadiusSwatch('md', 16, colors),
                _RadiusSwatch('lg', 24, colors),
                _RadiusSwatch('pill', 100, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.label(
          color: context.colors.textSecondary,
          weight: FontWeight.w700,
        ).copyWith(fontSize: 11, letterSpacing: 2),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.surfaceMuted, width: 1),
        boxShadow: [
          BoxShadow(
            color: context.colors.textPrimary.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot(this.name, this.color);
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 10,
            color: context.colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RadiusSwatch extends StatelessWidget {
  const _RadiusSwatch(this.label, this.radius, this.colors);
  final String label;
  final double radius;
  final ClothsyColorExtension colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 36,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(radius.clamp(0, 18)),
            border: Border.all(color: colors.accent.withOpacity(0.4)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
