import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shopper's last few searches, newest first, kept on the device.
class RecentSearchesNotifier extends Notifier<List<String>> {
  static const _key = 'clothsy_recent_searches_v1';
  static const max = 8;

  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_key) ?? const [];
      if (ref.mounted && state.isEmpty) state = saved;
    } catch (_) {
      // Recent searches are a convenience; never fail Search over them.
    }
  }

  Future<void> add(String term) async {
    final clean = term.trim();
    if (clean.length < 2) return;
    state = [
      clean,
      ...state.where((t) => t.toLowerCase() != clean.toLowerCase()),
    ].take(max).toList();
    await _save();
  }

  Future<void> clear() async {
    state = const [];
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, state);
    } catch (_) {}
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );
