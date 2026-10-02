import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clothsy_core/data/mappers/account_mappers.dart';
import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/address/domain/entities/pin_serviceability.dart';
import 'package:clothsy_core/features/address/domain/repositories/address_repository.dart';

/// Saved addresses; the database keeps exactly one default.
class SupabaseAddressRepository implements AddressRepository {
  final SupabaseClient _client;

  SupabaseAddressRepository(this._client);

  @override
  Future<List<Address>> getAddresses() async {
    final rows = await _client
        .from('addresses')
        .select()
        .order('is_default', ascending: false)
        .order('created_at');
    return rows.map(AccountMappers.address).toList();
  }

  @override
  Future<Address> addAddress(Address address) async {
    final row = await _client
        .from('addresses')
        .insert(AccountMappers.addressRow(address))
        .select()
        .single();
    return AccountMappers.address(row);
  }

  @override
  Future<Address> updateAddress(Address address) async {
    final row = await _client
        .from('addresses')
        .update(AccountMappers.addressRow(address))
        .eq('id', address.id)
        .select()
        .single();
    return AccountMappers.address(row);
  }

  @override
  Future<void> deleteAddress(String id) =>
      _client.from('addresses').delete().eq('id', id);

  @override
  Future<void> setDefaultAddress(String id) =>
      _client.rpc('set_default_address', params: {'p_id': id});

  @override
  Future<Map<String, String>?> lookupPinCode(String pinCode) async {
    final row = await _client
        .from('serviceable_pincodes')
        .select('city, state')
        .eq('pin_code', pinCode)
        .maybeSingle();
    if (row == null) return null;
    return {'city': row['city'] as String, 'state': row['state'] as String};
  }

  @override
  Future<PinServiceability> checkPinServiceability(String pinCode) async {
    final json = await _client.rpc(
      'check_pin_serviceability',
      params: {'p_pin': pinCode},
    );
    return AccountMappers.pin((json as Map).cast<String, dynamic>());
  }
}
