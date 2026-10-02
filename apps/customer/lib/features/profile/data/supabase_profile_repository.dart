import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clothsy_core/features/profile/domain/entities/style_preferences.dart';
import 'package:clothsy_core/features/profile/domain/repositories/profile_repository.dart';

/// Style preferences in `profiles.style_prefs`.
class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient _client;

  SupabaseProfileRepository(this._client);

  @override
  Future<StylePreferences?> getStylePreferences() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('profiles')
        .select('style_prefs')
        .eq('id', uid)
        .maybeSingle();
    final prefs = row?['style_prefs'];
    return prefs is Map
        ? StylePreferences.fromJson(prefs.cast<String, dynamic>())
        : null;
  }

  @override
  Future<void> saveStylePreferences(StylePreferences preferences) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('profiles')
        .update({'style_prefs': preferences.toJson()})
        .eq('id', uid);
  }
}
