import 'bootstrap.dart';
import 'package:clothsy_core/core/constants/app_constants.dart';

/// Default entrypoint (`flutter run`) — the mock flavor needs no backend or
/// keys. Use main_dev / main_staging / main_prod with a config file for real
/// environments.
void main() async {
  await bootstrap(flavor: AppFlavor.mock);
}
