import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(num amount) {
    final hasDecimals = (amount % 1) != 0;
    final formatter = NumberFormat.currency(
      symbol: AppConstants.defaultCurrencySymbol,
      decimalDigits: hasDecimals ? 2 : 0,
    );
    return formatter.format(amount);
  }
}
