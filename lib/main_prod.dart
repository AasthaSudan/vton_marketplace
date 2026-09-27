import 'bootstrap.dart';
import 'core/constants/app_constants.dart';

void main() async {
  await bootstrap(flavor: AppFlavor.prod);
}
