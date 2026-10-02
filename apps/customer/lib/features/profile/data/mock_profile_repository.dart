import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clothsy_core/features/profile/domain/entities/style_preferences.dart';
import 'package:clothsy_core/features/profile/domain/repositories/profile_repository.dart';

/// Keeps the taste profile on the device for the mock flavor.
class MockProfileRepository implements ProfileRepository {
  static const _key = 'clothsy_style_prefs_v1';

  @override
  Future<StylePreferences?> getStylePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return StylePreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveStylePreferences(StylePreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(preferences.toJson()));
  }
}
