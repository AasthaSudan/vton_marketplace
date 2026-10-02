import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/app_config_provider.dart';
import 'package:clothsy_core/core/constants/app_config.dart';
import 'package:clothsy_core/core/constants/app_constants.dart';

Future<void> bootstrap({required AppFlavor flavor}) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConstants.currentFlavor = flavor;

  final config = AppConfig.fromEnvironment(flavor);
  if (config.missingKeys.isNotEmpty) {
    throw StateError(
      'Missing ${config.missingKeys.join(', ')} for the ${flavor.name} flavor. '
      'Run with --dart-define-from-file=config/${flavor.name}.json '
      '(copy config/example.json to get started).',
    );
  }

  // Real backends: connect Supabase (the mock flavor never touches it).
  if (!config.useMockBackend) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: flavor == AppFlavor.dev,
    );
  }

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Lock to portrait mode initially
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const ClothsyShopApp(),
    ),
  );
}
