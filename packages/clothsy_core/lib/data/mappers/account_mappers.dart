import '../../features/address/domain/entities/address.dart';
import '../../features/address/domain/entities/pin_serviceability.dart';
import '../../features/auth/domain/entities/user.dart';

/// Maps profile, address and PIN rows to domain entities and back.
class AccountMappers {
  AccountMappers._();

  static User user({
    required String id,
    required Map<String, dynamic>? profile,
    String? phone,
    String? email,
  }) {
    return User(
      id: id,
      name: profile?['full_name'] as String? ?? '',
      email: profile?['email'] as String? ?? email ?? '',
      phone: profile?['phone'] as String? ?? phone ?? '',
      avatarUrl: profile?['avatar_url'] as String?,
      memberTier: profile?['member_tier'] as String? ?? 'Clothsy Member',
    );
  }

  static Address address(Map<String, dynamic> row) {
    return Address(
      id: row['id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String,
      street: row['line1'] as String,
      apartment: row['line2'] as String? ?? '',
      city: row['city'] as String,
      state: row['state'] as String,
      pinCode: row['pin_code'] as String,
      isDefault: row['is_default'] as bool? ?? false,
      label: row['label'] as String? ?? 'Home',
    );
  }

  /// Columns a shopper may write (the server fills id and owner).
  static Map<String, dynamic> addressRow(Address address) => {
    'label': address.label,
    'name': address.name,
    'phone': address.phone,
    'line1': address.street,
    'line2': address.apartment,
    'city': address.city,
    'state': address.state,
    'pin_code': address.pinCode,
    'is_default': address.isDefault,
  };

  static PinServiceability pin(Map<String, dynamic> json) {
    return PinServiceability(
      pinCode: json['pin_code'] as String? ?? '',
      serviceable: json['serviceable'] as bool? ?? false,
      codAvailable: json['cod_available'] as bool? ?? false,
      etaDays: (json['eta_days'] as num?)?.toInt() ?? 0,
      city: json['city'] as String?,
      state: json['state'] as String?,
    );
  }

  /// "98765 43210", "+91 98765 43210" and "919876543210" → "+919876543210".
  static String e164India(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    return '+$digits';
  }
}
