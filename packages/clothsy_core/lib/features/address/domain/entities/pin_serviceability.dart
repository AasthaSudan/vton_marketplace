/// Whether Clothsy delivers to a PIN code, and how (Blueprint section 26:
/// "Delivery & PIN check" on the product page).
class PinServiceability {
  final String pinCode;
  final bool serviceable;
  final bool codAvailable;

  /// Courier transit time in working days, once the seller has dispatched.
  final int etaDays;
  final String? city;
  final String? state;

  const PinServiceability({
    required this.pinCode,
    required this.serviceable,
    this.codAvailable = false,
    this.etaDays = 0,
    this.city,
    this.state,
  });

  const PinServiceability.unavailable(this.pinCode)
    : serviceable = false,
      codAvailable = false,
      etaDays = 0,
      city = null,
      state = null;
}

/// The date an order should arrive: [workingDays] after [from], counting
/// Monday to Saturday (couriers do not deliver on Sundays).
DateTime estimateDeliveryDate({
  required DateTime from,
  required int workingDays,
}) {
  var date = DateTime(from.year, from.month, from.day);
  var remaining = workingDays;
  while (remaining > 0) {
    date = date.add(const Duration(days: 1));
    if (date.weekday != DateTime.sunday) remaining--;
  }
  return date;
}
