import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/address/domain/repositories/address_repository.dart';

class MockAddressRepository implements AddressRepository {
  final List<Address> _addresses = [
    const Address(
      id: 'addr_1',
      name: 'Aastha Sudan',
      phone: '+91 98765 43210',
      street: 'Gulmohar Avenue, Vasant Vihar',
      apartment: 'Villa 14',
      city: 'New Delhi',
      state: 'Delhi',
      pinCode: '110057',
      isDefault: true,
      label: 'Home',
    ),
    const Address(
      id: 'addr_2',
      name: 'Aastha Sudan',
      phone: '+91 98765 43210',
      street: 'DLF Cyber City, Tower B',
      apartment: 'Suite 602',
      city: 'Gurugram',
      state: 'Haryana',
      pinCode: '122002',
      isDefault: false,
      label: 'Work',
    ),
  ];

  static const Map<String, Map<String, String>> _pinDatabase = {
    '110001': {'city': 'New Delhi', 'state': 'Delhi'},
    '110057': {'city': 'New Delhi', 'state': 'Delhi'},
    '122001': {'city': 'Gurugram', 'state': 'Haryana'},
    '122002': {'city': 'Gurugram', 'state': 'Haryana'},
    '400001': {'city': 'Mumbai', 'state': 'Maharashtra'},
    '400050': {'city': 'Bandra, Mumbai', 'state': 'Maharashtra'},
    '560001': {'city': 'Bengaluru', 'state': 'Karnataka'},
    '560038': {'city': 'Indiranagar, Bengaluru', 'state': 'Karnataka'},
    '500001': {'city': 'Hyderabad', 'state': 'Telangana'},
    '600001': {'city': 'Chennai', 'state': 'Tamil Nadu'},
    '700001': {'city': 'Kolkata', 'state': 'West Bengal'},
    '380001': {'city': 'Ahmedabad', 'state': 'Gujarat'},
    '302001': {'city': 'Jaipur', 'state': 'Rajasthan'},
  };

  @override
  Future<List<Address>> getAddresses() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.from(_addresses);
  }

  @override
  Future<Address> addAddress(Address address) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var newAddr = address;
    if (newAddr.isDefault) {
      for (var i = 0; i < _addresses.length; i++) {
        _addresses[i] = _addresses[i].copyWith(isDefault: false);
      }
    } else if (_addresses.isEmpty) {
      newAddr = newAddr.copyWith(isDefault: true);
    }
    _addresses.add(newAddr);
    return newAddr;
  }

  @override
  Future<Address> updateAddress(Address address) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _addresses.indexWhere((a) => a.id == address.id);
    if (index >= 0) {
      if (address.isDefault) {
        for (var i = 0; i < _addresses.length; i++) {
          _addresses[i] = _addresses[i].copyWith(isDefault: false);
        }
      }
      _addresses[index] = address;
    }
    return address;
  }

  @override
  Future<void> deleteAddress(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _addresses.removeWhere((a) => a.id == id);
    if (_addresses.isNotEmpty && !_addresses.any((a) => a.isDefault)) {
      _addresses[0] = _addresses[0].copyWith(isDefault: true);
    }
  }

  @override
  Future<void> setDefaultAddress(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    for (var i = 0; i < _addresses.length; i++) {
      _addresses[i] = _addresses[i].copyWith(isDefault: _addresses[i].id == id);
    }
  }

  @override
  Future<Map<String, String>?> lookupPinCode(String pinCode) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (_pinDatabase.containsKey(pinCode)) {
      return _pinDatabase[pinCode];
    }
    if (pinCode.length == 6) {
      // Default fallback for any 6-digit pin
      return {'city': 'Metropolitan Region', 'state': 'India'};
    }
    return null;
  }

  @override
  Future<bool> checkPinServiceability(String pinCode) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return pinCode.length == 6 && int.tryParse(pinCode) != null;
  }
}
