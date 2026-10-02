import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:clothsy_core/features/address/domain/entities/pin_serviceability.dart';
import '../../../../core/config/app_config_provider.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/mock_address_repository.dart';
import '../../data/repositories/supabase_address_repository.dart';
import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/address/domain/repositories/address_repository.dart';

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockBackend) {
    return MockAddressRepository();
  }
  return SupabaseAddressRepository(ref.watch(supabaseClientProvider));
});

/// Delivery, COD and transit time for a PIN code (cached per PIN).
final pinServiceabilityProvider =
    FutureProvider.family<PinServiceability, String>((ref, pinCode) {
      return ref
          .watch(addressRepositoryProvider)
          .checkPinServiceability(pinCode);
    });

/// "Tue, 8 Oct": when an order shipped after [dispatchDays] and in transit
/// for [transitDays] working days should arrive.
String arrivesByLabel({required int dispatchDays, required int transitDays}) {
  final date = estimateDeliveryDate(
    from: DateTime.now(),
    workingDays: dispatchDays + transitDays,
  );
  return DateFormat('EEE, d MMM').format(date);
}

class AddressesNotifier extends Notifier<List<Address>> {
  @override
  List<Address> build() {
    _loadAddresses();
    return [];
  }

  Future<void> _loadAddresses() async {
    final repo = ref.read(addressRepositoryProvider);
    final list = await repo.getAddresses();
    if (!ref.mounted) return;
    state = list;
    // Auto-select default if none selected yet
    if (list.isNotEmpty) {
      final defaultAddr = list.firstWhere(
        (a) => a.isDefault,
        orElse: () => list.first,
      );
      ref.read(selectedAddressProvider.notifier).select(defaultAddr);
    }
  }

  Future<void> addAddress(Address address) async {
    final repo = ref.read(addressRepositoryProvider);
    final created = await repo.addAddress(address);
    final updatedList = await repo.getAddresses();
    state = updatedList;
    if (created.isDefault || state.length == 1) {
      ref.read(selectedAddressProvider.notifier).select(created);
    }
  }

  Future<void> updateAddress(Address address) async {
    final repo = ref.read(addressRepositoryProvider);
    await repo.updateAddress(address);
    final updatedList = await repo.getAddresses();
    state = updatedList;
  }

  Future<void> deleteAddress(String id) async {
    final repo = ref.read(addressRepositoryProvider);
    await repo.deleteAddress(id);
    final updatedList = await repo.getAddresses();
    state = updatedList;
    if (ref.read(selectedAddressProvider)?.id == id) {
      final newSelected = updatedList.isNotEmpty ? updatedList.first : null;
      ref.read(selectedAddressProvider.notifier).select(newSelected);
    }
  }

  Future<void> setDefaultAddress(String id) async {
    final repo = ref.read(addressRepositoryProvider);
    await repo.setDefaultAddress(id);
    final updatedList = await repo.getAddresses();
    state = updatedList;
    final match = updatedList.firstWhere(
      (a) => a.id == id,
      orElse: () => updatedList.first,
    );
    ref.read(selectedAddressProvider.notifier).select(match);
  }
}

final addressesProvider = NotifierProvider<AddressesNotifier, List<Address>>(
  AddressesNotifier.new,
);

class SelectedAddressNotifier extends Notifier<Address?> {
  @override
  Address? build() => null;

  void select(Address? address) => state = address;
}

final selectedAddressProvider =
    NotifierProvider<SelectedAddressNotifier, Address?>(
      SelectedAddressNotifier.new,
    );
