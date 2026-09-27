import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/buttons/clothsy_icon_button.dart';
import '../../../shared/widgets/buttons/pressable_scale.dart';
import '../../../shared/widgets/buttons/primary_button.dart';
import '../../../shared/widgets/feedback/clothsy_snackbar.dart';
import '../../../shared/widgets/inputs/clothsy_text_field.dart';
import '../domain/entities/address.dart';
import 'providers/address_providers.dart';

class AddEditAddressScreen extends ConsumerStatefulWidget {
  final Address? initialAddress;

  const AddEditAddressScreen({super.key, this.initialAddress});

  @override
  ConsumerState<AddEditAddressScreen> createState() =>
      _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends ConsumerState<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _pinController;
  late TextEditingController _streetController;
  late TextEditingController _aptController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;

  String _label = 'Home';
  bool _isDefault = false;
  bool _isLookingUpPin = false;

  @override
  void initState() {
    super.initState();
    final addr = widget.initialAddress;
    _nameController = TextEditingController(text: addr?.name ?? 'Aastha Sudan');
    _phoneController = TextEditingController(
      text: addr?.phone ?? '+91 98765 43210',
    );
    _pinController = TextEditingController(text: addr?.pinCode ?? '');
    _streetController = TextEditingController(text: addr?.street ?? '');
    _aptController = TextEditingController(text: addr?.apartment ?? '');
    _cityController = TextEditingController(text: addr?.city ?? '');
    _stateController = TextEditingController(text: addr?.state ?? '');
    _label = addr?.label ?? 'Home';
    _isDefault = addr?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _streetController.dispose();
    _aptController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _onPinChanged(String pin) async {
    if (pin.length == 6) {
      setState(() => _isLookingUpPin = true);
      final repo = ref.read(addressRepositoryProvider);
      final info = await repo.lookupPinCode(pin);
      setState(() => _isLookingUpPin = false);
      if (info != null) {
        _cityController.text = info['city'] ?? '';
        _stateController.text = info['state'] ?? '';
      }
    }
  }

  Future<void> _saveAddress() async {
    if (_nameController.text.trim().isEmpty ||
        _streetController.text.trim().isEmpty ||
        _pinController.text.trim().length != 6) {
      ClothsySnackbar.show(
        context,
        message: 'Please fill in all mandatory fields with a 6-digit PIN',
        type: SnackbarType.error,
      );
      return;
    }

    final newAddress = Address(
      id:
          widget.initialAddress?.id ??
          'addr_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      street: _streetController.text.trim(),
      apartment: _aptController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? 'City'
          : _cityController.text.trim(),
      state: _stateController.text.trim().isEmpty
          ? 'State'
          : _stateController.text.trim(),
      pinCode: _pinController.text.trim(),
      isDefault: _isDefault,
      label: _label,
    );

    if (widget.initialAddress != null) {
      await ref.read(addressesProvider.notifier).updateAddress(newAddress);
      if (mounted) {
        ClothsySnackbar.show(
          context,
          message: 'Address updated successfully',
          type: SnackbarType.success,
        );
        context.pop();
      }
    } else {
      await ref.read(addressesProvider.notifier).addAddress(newAddress);
      if (mounted) {
        ClothsySnackbar.show(
          context,
          message: 'Address saved to your address book',
          type: SnackbarType.success,
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEditing = widget.initialAddress != null;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Delivery Address' : 'Add New Address',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ClothsyIconButton(
            size: 38,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: colors.primary,
            ),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Contact details
              Text(
                'Contact Person',
                style: AppTypography.bodyMedium(weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ClothsyTextField(
                label: 'Full Name *',
                hint: 'e.g. Aastha Sudan',
                controller: _nameController,
              ),
              const SizedBox(height: 14),
              ClothsyTextField(
                label: 'Phone Number *',
                hint: '+91 98765 43210',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // Address details
              Text(
                'Address Information',
                style: AppTypography.bodyMedium(weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: ClothsyTextField(
                      label: 'PIN Code *',
                      hint: '110001',
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      onChanged: _onPinChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: ClothsyTextField(
                      label: 'City / District *',
                      hint: _isLookingUpPin ? 'Detecting...' : 'City',
                      controller: _cityController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClothsyTextField(
                label: 'State *',
                hint: 'State',
                controller: _stateController,
              ),
              const SizedBox(height: 14),
              ClothsyTextField(
                label: 'Building / Apartment / Villa',
                hint: 'e.g. Apartment 402, Royal Residency',
                controller: _aptController,
              ),
              const SizedBox(height: 14),
              ClothsyTextField(
                label: 'Street / Area / Landmark *',
                hint: 'e.g. Vasant Vihar, Near Central Park',
                controller: _streetController,
              ),
              const SizedBox(height: 24),

              // Address Label Selector (Home, Work, Other)
              Text(
                'Address Type',
                style: AppTypography.bodyMedium(weight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: ['Home', 'Work', 'Other'].map((l) {
                  final isSelected = _label == l;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: PressableScale(
                      onTap: () => setState(() => _label = l),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.primary : colors.surface,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isSelected ? colors.primary : colors.border,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          l,
                          style: AppTypography.caption(
                            color: isSelected
                                ? colors.onPrimary
                                : colors.textPrimary,
                            weight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Set as default switch
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: colors.border.withOpacity(0.6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set as Default Address',
                          style: AppTypography.bodyMedium(
                            weight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Use this address for all future checkouts',
                          style: AppTypography.caption(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _isDefault,
                      activeColor: colors.primary,
                      onChanged: (val) => setState(() => _isDefault = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              PrimaryButton(
                text: isEditing ? 'Save Changes' : 'Save Address',
                onPressed: _saveAddress,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
