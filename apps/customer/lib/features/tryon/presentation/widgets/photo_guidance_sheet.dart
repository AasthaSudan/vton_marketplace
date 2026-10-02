import 'package:flutter/material.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';

/// Photo tips and the consent notice shown before a shopper uses their own
/// photo (Blueprint fig. 27). Model photos need no consent; the shopper's
/// own camera or gallery photo does, and the box starts unticked.
class PhotoGuidanceSheet extends StatefulWidget {
  final bool alreadyConsented;
  final VoidCallback onConsentGranted;
  final VoidCallback onCameraSelected;
  final VoidCallback onGallerySelected;
  final VoidCallback onPresetSelected;

  const PhotoGuidanceSheet({
    super.key,
    this.alreadyConsented = false,
    required this.onConsentGranted,
    required this.onCameraSelected,
    required this.onGallerySelected,
    required this.onPresetSelected,
  });

  static Future<void> show(
    BuildContext context, {
    bool alreadyConsented = false,
    required VoidCallback onConsentGranted,
    required VoidCallback onCameraSelected,
    required VoidCallback onGallerySelected,
    required VoidCallback onPresetSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhotoGuidanceSheet(
        alreadyConsented: alreadyConsented,
        onConsentGranted: onConsentGranted,
        onCameraSelected: onCameraSelected,
        onGallerySelected: onGallerySelected,
        onPresetSelected: onPresetSelected,
      ),
    );
  }

  @override
  State<PhotoGuidanceSheet> createState() => _PhotoGuidanceSheetState();
}

class _PhotoGuidanceSheetState extends State<PhotoGuidanceSheet> {
  late bool _agreedToPrivacy = widget.alreadyConsented;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title & Sparkle Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Try it on with your photo',
                      style: AppTypography.h3(color: colors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A few tips for a great preview',
                      style: AppTypography.caption(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3 Guidance Rules
          _buildGuidanceItem(
            context,
            icon: Icons.person_outline,
            title: 'Full or upper body in view',
            description:
                'Stand naturally facing the camera with arms relaxed at your sides.',
          ),
          const SizedBox(height: 12),
          _buildGuidanceItem(
            context,
            icon: Icons.wb_sunny_outlined,
            title: 'Soft, even light',
            description:
                'Avoid strong backlighting or heavy shadows across your clothes.',
          ),
          const SizedBox(height: 12),
          _buildGuidanceItem(
            context,
            icon: Icons.wallpaper_outlined,
            title: 'Plain background',
            description:
                'A plain wall or uncluttered space gives the most realistic preview.',
          ),
          const SizedBox(height: 20),

          // Privacy & Consent Checkbox
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreedToPrivacy,
                    activeColor: colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _agreedToPrivacy = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'I agree to how my photo is used',
                        style: AppTypography.bodyMedium(
                          weight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ClothsyCopy.tryOnConsent,
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Actions
          PrimaryButton(
            text: 'Take a photo',
            icon: const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 18,
            ),
            onPressed: _agreedToPrivacy
                ? () {
                    Navigator.pop(context);
                    widget.onConsentGranted();
                    widget.onCameraSelected();
                  }
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _agreedToPrivacy
                      ? () {
                          Navigator.pop(context);
                          widget.onConsentGranted();
                          widget.onGallerySelected();
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius,
                    ),
                  ),
                  icon: Icon(
                    Icons.photo_library_outlined,
                    size: 18,
                    color: colors.textPrimary,
                  ),
                  label: Text(
                    'From gallery',
                    style: AppTypography.bodyMedium(
                      weight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onPresetSelected();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius,
                    ),
                  ),
                  icon: Icon(
                    Icons.face_retouching_natural,
                    size: 18,
                    color: colors.textPrimary,
                  ),
                  label: Text(
                    'Use a model',
                    style: AppTypography.bodyMedium(
                      weight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colors.textPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium(
                  weight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.caption(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
