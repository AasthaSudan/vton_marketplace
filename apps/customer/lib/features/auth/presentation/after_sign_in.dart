import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/features/profile/domain/entities/style_preferences.dart';
import '../../profile/presentation/providers/profile_providers.dart';

/// Sends a freshly signed-in shopper on: to style onboarding the first time
/// (Blueprint fig. 13), otherwise straight to [redirect] (e.g. checkout).
Future<void> goAfterSignIn(
  BuildContext context,
  WidgetRef ref,
  String? redirect,
) async {
  final target = redirect != null && redirect.isNotEmpty ? redirect : '/';
  StylePreferences? preferences;
  try {
    preferences = await ref
        .read(profileRepositoryProvider)
        .getStylePreferences();
  } catch (_) {
    // Personalisation must never block signing in.
    preferences = const StylePreferences();
  }
  if (!context.mounted) return;
  if (preferences == null) {
    context.go(
      '/style-preferences?redirect=${Uri.encodeQueryComponent(target)}',
    );
  } else {
    context.go(target);
  }
}
