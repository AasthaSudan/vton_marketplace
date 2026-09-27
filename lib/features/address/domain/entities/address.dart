class Address {
  final String id;
  final String name;
  final String phone;
  final String street;
  final String apartment;
  final String city;
  final String state;
  final String pinCode;
  final bool isDefault;
  final String label; // Home, Work, Other

  const Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.street,
    this.apartment = '',
    required this.city,
    required this.state,
    required this.pinCode,
    this.isDefault = false,
    this.label = 'Home',
  });

  String get formattedAddress {
    final apt = apartment.isNotEmpty ? '$apartment, ' : '';
    return '$apt$street, $city, $state - $pinCode';
  }

  Address copyWith({
    String? id,
    String? name,
    String? phone,
    String? street,
    String? apartment,
    String? city,
    String? state,
    String? pinCode,
    bool? isDefault,
    String? label,
  }) {
    return Address(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      street: street ?? this.street,
      apartment: apartment ?? this.apartment,
      city: city ?? this.city,
      state: state ?? this.state,
      pinCode: pinCode ?? this.pinCode,
      isDefault: isDefault ?? this.isDefault,
      label: label ?? this.label,
    );
  }
}
