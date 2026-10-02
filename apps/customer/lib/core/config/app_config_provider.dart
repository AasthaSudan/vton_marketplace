import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/core/constants/app_config.dart';
import 'package:clothsy_core/core/constants/app_constants.dart';

/// The active [AppConfig]. Overridden in `bootstrap()`; defaults to a
/// keyless config for the current flavor (mock backend) in tests.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig(flavor: AppConstants.currentFlavor);
});
