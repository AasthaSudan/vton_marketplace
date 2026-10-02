import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Formats money for display.
///
/// Every amount in Clothsy is stored as integer **paise** (₹1 = 100 paise) so
/// totals never suffer floating-point rounding. Convert to rupees only here,
/// at the edge of the UI.
class CurrencyFormatter {
  CurrencyFormatter._();

  static const int paisePerRupee = 100;

  /// `149900` → `₹1,499`, `149950` → `₹1,499.50`, `12345600` → `₹1,23,456`.
  static String format(int paise) {
    final hasPaise = paise % paisePerRupee != 0;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: AppConstants.defaultCurrencySymbol,
      decimalDigits: hasPaise ? 2 : 0,
    );
    return formatter.format(paise / paisePerRupee);
  }

  /// Converts whole rupees to paise, e.g. `fromRupees(1499)` → `149900`.
  static int fromRupees(num rupees) => (rupees * paisePerRupee).round();
}
