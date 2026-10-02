import 'package:clothsy_core/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/providers.dart';
import 'data/supabase_seller_repository.dart';

/// The Seller Panel lets brands of every size run their store on Clothsy
/// (Brand Blueprint, Part 07).
///
/// ```bash
/// flutter run -d chrome --dart-define-from-file=config/dev.json
/// ```
/// (`scripts/backend.sh up` writes config/dev.json for the local backend.)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isEmpty || anonKey.isEmpty) {
    runApp(const _NotConfigured());
    return;
  }
  await Supabase.initialize(url: url, anonKey: anonKey);
  runApp(
    ProviderScope(
      // Show errors straight away instead of retrying in the background.
      retry: (_, _) => null,
      overrides: [
        sellerRepositoryProvider.overrideWithValue(
          SupabaseSellerRepository(Supabase.instance.client),
        ),
      ],
      child: const ClothsySellerApp(),
    ),
  );
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'The Seller Panel needs a backend. Start the local one with '
              'scripts/backend.sh up, then run with '
              '--dart-define-from-file=config/dev.json.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
