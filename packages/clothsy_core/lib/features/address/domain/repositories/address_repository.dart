import '../entities/address.dart';

abstract class AddressRepository {
  Future<List<Address>> getAddresses();
  Future<Address> addAddress(Address address);
  Future<Address> updateAddress(Address address);
  Future<void> deleteAddress(String id);
  Future<void> setDefaultAddress(String id);
  Future<Map<String, String>?> lookupPinCode(String pinCode);
  Future<bool> checkPinServiceability(String pinCode);
}
