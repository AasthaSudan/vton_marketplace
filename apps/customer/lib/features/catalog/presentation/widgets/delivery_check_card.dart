import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/features/address/domain/entities/pin_serviceability.dart';
import 'package:clothsy_core/features/catalog/domain/entities/seller.dart';
import '../../../address/presentation/providers/address_providers.dart';

/// "Delivery & PIN check" and the seller's return policy on the product page
/// (Blueprint section 26). The delivery date is the seller's dispatch time
/// plus the courier's transit time to the PIN.
class DeliveryCheckCard extends ConsumerStatefulWidget {
  final Seller? seller;

  const DeliveryCheckCard({super.key, required this.seller});

  @override
  ConsumerState<DeliveryCheckCard> createState() => _DeliveryCheckCardState();
}

class _DeliveryCheckCardState extends ConsumerState<DeliveryCheckCard> {
  final _pin = TextEditingController();
  PinServiceability? _result;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(selectedAddressProvider)?.pinCode;
    if (saved != null) {
      _pin.text = saved;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final pin = _pin.text.trim();
    if (pin.length != 6) return;
    FocusScope.of(context).unfocus();
    setState(() => _checking = true);
    final result = await ref
        .read(addressRepositoryProvider)
        .checkPinServiceability(pin);
    if (!mounted) return;
    setState(() {
      _result = result;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final seller = widget.seller;
    final dispatchDays = seller?.dispatchDays ?? 2;
    final returnDays = seller?.returnWindowDays ?? 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery & returns',
            style: AppTypography.bodyMedium(
              color: colors.textPrimary,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _check(),
                    style: AppTypography.bodyMedium(color: colors.textPrimary),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Enter delivery PIN code',
                      prefixIcon: Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide(color: colors.border),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _checking ? null : _check,
                child: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Check',
                        style: AppTypography.bodyMedium(
                          color: colors.primary,
                          weight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(
            context,
            icon: Icons.local_shipping_outlined,
            title: _deliveryTitle(dispatchDays),
            subtitle: _deliverySubtitle(dispatchDays),
            highlight: _result?.serviceable == false,
          ),
          if (_result?.serviceable == true) ...[
            const SizedBox(height: 10),
            _row(
              context,
              icon: Icons.payments_outlined,
              title: _result!.codAvailable
                  ? 'Cash on delivery available'
                  : 'Pay online for this PIN',
              subtitle: _result!.codAvailable
                  ? 'Pay by cash or UPI when it arrives.'
                  : 'Cash on delivery is not offered here yet.',
            ),
          ],
          const SizedBox(height: 10),
          _row(
            context,
            icon: Icons.assignment_return_outlined,
            title: returnDays > 0
                ? '$returnDays-day returns & exchanges'
                : 'Not returnable',
            subtitle: returnDays > 0
                ? 'Return or exchange within $returnDays days of delivery.'
                : "This piece can't be returned. Check the size before you buy.",
          ),
        ],
      ),
    );
  }

  String _deliveryTitle(int dispatchDays) {
    final result = _result;
    if (result == null) return 'Ships in $dispatchDays working days';
    if (!result.serviceable) {
      return "We don't deliver to ${result.pinCode} yet";
    }
    final date = estimateDeliveryDate(
      from: DateTime.now(),
      workingDays: dispatchDays + result.etaDays,
    );
    return 'Delivery by ${DateFormat('EEE, d MMM').format(date)}';
  }

  String _deliverySubtitle(int dispatchDays) {
    final result = _result;
    final seller = widget.seller?.name ?? 'The seller';
    if (result == null) {
      return 'Enter your PIN for a delivery date. $seller ships it.';
    }
    if (!result.serviceable) return 'Try another PIN code.';
    return 'To ${result.city ?? result.pinCode}, shipped by $seller.';
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    bool highlight = false,
  }) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: highlight ? colors.warning : colors.primary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium(
                  color: colors.textPrimary,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
