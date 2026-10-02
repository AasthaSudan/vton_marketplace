import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/features/profile/domain/entities/style_preferences.dart';
import 'package:clothsy_core/features/profile/domain/repositories/profile_repository.dart';
import '../../../../core/config/app_config_provider.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../data/mock_profile_repository.dart';
import '../../data/supabase_profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockBackend) {
    return MockProfileRepository();
  }
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in shopper's taste profile (null until onboarding was shown).
final stylePreferencesProvider = FutureProvider<StylePreferences?>((ref) {
  return ref.watch(profileRepositoryProvider).getStylePreferences();
});
