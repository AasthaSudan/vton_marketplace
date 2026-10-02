import 'bootstrap.dart';
import 'package:clothsy_core/core/constants/app_constants.dart';

void main() async {
  await bootstrap(flavor: AppFlavor.prod);
}
