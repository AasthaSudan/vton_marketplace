import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/core/constants/app_constants.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import '../../../app.dart';
import '../../tryon/presentation/providers/tryon_provider.dart';

/// Settings & privacy (Blueprint section 32): appearance, Try-On photo
/// controls ("delete it anytime from Settings" — the consent promise) and
/// legal information.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final colors = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(title, style: AppTypography.h3(color: colors.textPrimary)),
        content: Text(
          message,
          style: AppTypography.body(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Keep',
              style: AppTypography.bodyMedium(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              action,
              style: AppTypography.bodyMedium(
                color: colors.error,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _setConsent(
    BuildContext context,
    WidgetRef ref,
    bool consented,
  ) async {
    final notifier = ref.read(tryOnNotifierProvider.notifier);
    if (consented) {
      await notifier.grantConsent();
      return;
    }
    final ok = await _confirm(
      context,
      title: 'Stop using your photos?',
      message:
          'Your try-on photos and the previews made from them will be '
          'deleted. You can still try things on with our model photos.',
      action: 'Turn off & delete',
    );
    if (!ok) return;
    await notifier.revokeConsent();
    if (context.mounted) {
      ClothsySnackbar.show(
        context,
        message: 'Your try-on photos and previews were deleted.',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _deletePhotos(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Delete your try-on photos?',
      message:
          'This removes every photo you added and the previews made from '
          'them. It cannot be undone.',
      action: 'Delete',
    );
    if (!ok) return;
    await ref.read(tryOnNotifierProvider.notifier).deleteMyPhotos();
    if (context.mounted) {
      ClothsySnackbar.show(
        context,
        message: 'Your try-on photos and previews were deleted.',
        type: SnackbarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider);
    final consented = ref.watch(
      tryOnNotifierProvider.select((s) => s.hasConsented),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Settings & privacy',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Section(
            title: 'Appearance',
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Phone'),
                  ),
                ],
                selected: {themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(selection.first),
              ),
            ],
          ),
          _Section(
            title: 'Clothsy AI Try-On',
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: consented,
                activeTrackColor: colors.primary,
                onChanged: (value) => _setConsent(context, ref, value),
                title: Text(
                  'Use my own photos',
                  style: AppTypography.bodyMedium(
                    color: colors.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Only to create your try-on previews. Turning this off '
                  'deletes them.',
                  style: AppTypography.caption(color: colors.textSecondary),
                ),
              ),
              const SizedBox(height: 4),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete my try-on photos',
                subtitle:
                    'Photos are deleted automatically after '
                    '${AppConstants.tryOnPhotoRetention.inDays} days.',
                destructive: true,
                onTap: () => _deletePhotos(context, ref),
              ),
            ],
          ),
          _Section(
            title: 'About',
            children: [
              _ActionTile(
                icon: Icons.policy_outlined,
                title: 'Terms, privacy & return policies',
                subtitle: 'Published before launch.',
                onTap: () => ClothsySnackbar.show(
                  context,
                  message: 'Our policies will be published here before launch.',
                ),
              ),
              _ActionTile(
                icon: Icons.info_outline_rounded,
                title: '${AppConstants.appName} 1.0.0',
                subtitle: AppConstants.appTagline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium(
              color: colors.textSecondary,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: colors.border.withOpacity(0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = destructive ? colors.error : colors.textPrimary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: destructive ? colors.error : colors.primary),
      title: Text(
        title,
        style: AppTypography.bodyMedium(color: color, weight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption(color: colors.textSecondary),
      ),
      onTap: onTap,
    );
  }
}
