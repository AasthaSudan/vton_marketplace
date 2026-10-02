import '../entities/style_preferences.dart';

/// The shopper's taste profile, stored with their account.
abstract class ProfileRepository {
  /// Null until onboarding has been finished or skipped.
  Future<StylePreferences?> getStylePreferences();

  Future<void> saveStylePreferences(StylePreferences preferences);
}
