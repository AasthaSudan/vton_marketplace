import '../entities/address.dart';
import '../entities/pin_serviceability.dart';

abstract class AddressRepository {
  Future<List<Address>> getAddresses();
  Future<Address> addAddress(Address address);
  Future<Address> updateAddress(Address address);
  Future<void> deleteAddress(String id);
  Future<void> setDefaultAddress(String id);
  Future<Map<String, String>?> lookupPinCode(String pinCode);

  /// Delivery, cash-on-delivery and transit time for [pinCode].
  Future<PinServiceability> checkPinServiceability(String pinCode);
}
