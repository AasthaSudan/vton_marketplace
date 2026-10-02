import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/features/profile/domain/entities/style_preferences.dart';
import 'package:clothsy_core/features/profile/domain/repositories/profile_repository.dart';
import '../../data/mock_profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return MockProfileRepository();
});

/// The signed-in shopper's taste profile (null until onboarding was shown).
final stylePreferencesProvider = FutureProvider<StylePreferences?>((ref) {
  return ref.watch(profileRepositoryProvider).getStylePreferences();
});
