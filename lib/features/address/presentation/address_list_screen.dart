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
import '../../../shared/widgets/feedback/empty_state_view.dart';
import 'add_edit_address_screen.dart';
import 'providers/address_providers.dart';

class AddressListScreen extends ConsumerWidget {
  final bool isSelectingForCheckout;

  const AddressListScreen({super.key, this.isSelectingForCheckout = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final addresses = ref.watch(addressesProvider);
    final selectedAddress = ref.watch(selectedAddressProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          isSelectingForCheckout ? 'Choose Delivery Address' : 'My Addresses',
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
      body: addresses.isEmpty
          ? EmptyStateView(
              icon: Icons.location_off_outlined,
              title: 'No Addresses Found',
              message:
                  'Add your delivery location to ensure swift and seamless doorstep arrival.',
              actionText: 'Add New Address',
              onActionPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddEditAddressScreen(),
                  ),
                );
              },
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                ...addresses.map((address) {
                  final isSelected = selectedAddress?.id == address.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: PressableScale(
                      onTap: () {
                        ref
                            .read(selectedAddressProvider.notifier)
                            .select(address);
                        if (isSelectingForCheckout) {
                          context.pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: AppRadius.cardRadius,
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : colors.border.withOpacity(0.6),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colors.primary.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row: Label chip, Default badge, radio selection
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                      ),
                                      child: Text(
                                        address.label.toUpperCase(),
                                        style: AppTypography.label(
                                          color: colors.primary,
                                          weight: FontWeight.w700,
                                        ).copyWith(fontSize: 10),
                                      ),
                                    ),
                                    if (address.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.accentSoft,
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                        ),
                                        child: Text(
                                          'DEFAULT',
                                          style: AppTypography.label(
                                            color: colors.primary,
                                            weight: FontWeight.w700,
                                          ).copyWith(fontSize: 9),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_off,
                                  color: isSelected
                                      ? colors.primary
                                      : colors.textSecondary.withOpacity(0.5),
                                  size: 22,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Recipient Name & Phone
                            Text(
                              address.name,
                              style: AppTypography.bodyMedium(
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              address.phone,
                              style: AppTypography.caption(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Formatted street and postal address
                            Text(
                              address.formattedAddress,
                              style: AppTypography.body(
                                color: colors.textPrimary,
                              ).copyWith(fontSize: 14),
                            ),
                            const SizedBox(height: 14),
                            Divider(color: colors.border.withOpacity(0.5)),
                            const SizedBox(height: 8),

                            // Action buttons (Set as default, Edit, Delete)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!address.isDefault)
                                  TextButton(
                                    onPressed: () {
                                      ref
                                          .read(addressesProvider.notifier)
                                          .setDefaultAddress(address.id);
                                      ClothsySnackbar.show(
                                        context,
                                        message: 'Default address updated',
                                        type: SnackbarType.success,
                                      );
                                    },
                                    child: Text(
                                      'Set as Default',
                                      style: AppTypography.caption(
                                        color: colors.primary,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                    color: colors.primary,
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AddEditAddressScreen(
                                          initialAddress: address,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                    color: colors.error,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(addressesProvider.notifier)
                                        .deleteAddress(address.id);
                                    ClothsySnackbar.show(
                                      context,
                                      message: 'Address removed',
                                      type: SnackbarType.info,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                PrimaryButton(
                  text: 'Add New Address',
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddEditAddressScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
