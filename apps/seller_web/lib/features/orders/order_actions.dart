import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../../data/seller_repository.dart';
import '../../printing/invoice_pdf.dart';
import '../../widgets/panel_widgets.dart';

/// Couriers offered when shipping by hand (until a courier partner books
/// pickups automatically).
const couriers = [
  'Delhivery',
  'Blue Dart',
  'Xpressbees',
  'Ecom Express',
  'Shadowfax',
  'DTDC',
  'India Post',
];

/// The fulfilment steps, with the same error handling and refresh
/// everywhere they appear (list and detail).
///
/// A step often moves the order to another tab, which removes the card it
/// was started from, so the follow-ups (print, messages) use the app's
/// provider container and navigator rather than the card's.
class OrderActions {
  final ProviderContainer _container;
  final BuildContext context;

  OrderActions(BuildContext from)
    : _container = ProviderScope.containerOf(from, listen: false),
      context = Navigator.of(from, rootNavigator: true).context;

  void _refresh() {
    _container.invalidate(ordersProvider);
    _container.invalidate(dashboardProvider);
  }

  Future<bool> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      _refresh();
      if (context.mounted) showDone(context, done);
      return true;
    } catch (e) {
      if (context.mounted) showFailure(context, e);
      _refresh();
      return false;
    }
  }

  Future<void> accept(SellerOrder order) => _run(
    () => _container.read(sellerRepositoryProvider).acceptOrder(order.id),
    'Accepted ${order.reference}',
  );

  Future<void> pack(SellerOrder order) async {
    String? invoice;
    final ok = await _run(() async {
      invoice = await _container
          .read(sellerRepositoryProvider)
          .packOrder(order.id);
    }, 'Packed — invoice created');
    if (ok && invoice != null && context.mounted) {
      final print = await confirm(
        context,
        title: 'Print the invoice and label?',
        message:
            'Invoice $invoice is ready. Put a copy in the parcel and stick '
            'the label on the outside.',
        confirmText: 'Print',
      );
      if (print) await printDocuments(order);
    }
  }

  Future<void> printDocuments(SellerOrder order) async {
    try {
      final data = await _container
          .read(sellerRepositoryProvider)
          .invoice(order.id);
      final bytes = await buildInvoicePdf(data);
      await _container.read(printPdfProvider)(
        bytes,
        'Clothsy-${(data['invoice_number'] as String).replaceAll('/', '-')}',
      );
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> ship(SellerOrder order) async {
    final details = await showDialog<_ShipDetails>(
      context: context,
      builder: (_) => const _ShipDialog(),
    );
    if (details == null) return;
    await _run(
      () => _container
          .read(sellerRepositoryProvider)
          .shipOrder(
            order.id,
            carrier: details.carrier,
            trackingNumber: details.awb,
            trackingUrl: details.url,
          ),
      'Marked as shipped',
    );
  }

  Future<void> markDelivered(SellerOrder order) async {
    final sure = await confirm(
      context,
      title: 'Mark as delivered?',
      message:
          'Only when the courier confirms delivery. The return window starts '
          'now, and your payout follows when it closes.',
      confirmText: 'Delivered',
    );
    if (!sure) return;
    await _run(
      () => _container.read(sellerRepositoryProvider).markDelivered(order.id),
      'Marked as delivered',
    );
  }

  Future<void> cancel(SellerOrder order) async {
    final reason = await askText(
      context,
      title: 'Cancel ${order.reference}?',
      label: 'Reason the shopper will see',
      confirmText: 'Cancel order',
    );
    if (reason == null) return;
    if (reason.trim().isEmpty) {
      if (context.mounted) {
        showFailure(context, const SellerFailure('REASON_REQUIRED'));
      }
      return;
    }
    await _run(
      () => _container
          .read(sellerRepositoryProvider)
          .cancelOrder(order.id, reason),
      'Cancelled — the shopper is refunded automatically',
    );
  }
}

class _ShipDetails {
  final String carrier;
  final String awb;
  final String? url;

  const _ShipDetails(this.carrier, this.awb, this.url);
}

class _ShipDialog extends StatefulWidget {
  const _ShipDialog();

  @override
  State<_ShipDialog> createState() => _ShipDialogState();
}

class _ShipDialogState extends State<_ShipDialog> {
  final _form = GlobalKey<FormState>();
  final _awb = TextEditingController();
  final _url = TextEditingController();
  final _other = TextEditingController();
  String _carrier = couriers.first;

  @override
  void dispose() {
    _awb.dispose();
    _url.dispose();
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hand over to the courier'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _carrier,
                decoration: const InputDecoration(
                  labelText: 'Courier',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in [...couriers, 'Other'])
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _carrier = v!),
              ),
              if (_carrier == 'Other') ...[
                const SizedBox(height: 12),
                FieldBox(
                  label: 'Courier name',
                  controller: _other,
                  width: double.infinity,
                  validator: (v) =>
                      (v ?? '').trim().length < 2 ? 'Enter the courier' : null,
                ),
              ],
              const SizedBox(height: 12),
              FieldBox(
                label: 'Tracking (AWB) number',
                controller: _awb,
                width: double.infinity,
                validator: (v) =>
                    RegExp(r'^[A-Za-z0-9-]{6,30}$').hasMatch((v ?? '').trim())
                    ? null
                    : '6 to 30 letters or digits',
              ),
              const SizedBox(height: 12),
              FieldBox(
                label: 'Tracking link (optional)',
                controller: _url,
                width: double.infinity,
                hint: 'https://…',
                validator: (v) =>
                    (v ?? '').trim().isEmpty ||
                        (v ?? '').trim().startsWith('https://')
                    ? null
                    : 'Starts with https://',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ShipDetails(
                _carrier == 'Other' ? _other.text.trim() : _carrier,
                _awb.text.trim(),
                _url.text.trim().isEmpty ? null : _url.text.trim(),
              ),
            );
          },
          child: const Text('Mark shipped'),
        ),
      ],
    );
  }
}

/// The next step's button for an order, or null when nothing is due.
Widget? nextStepButton(OrderActions actions, SellerOrder order) {
  if (order.canAccept) {
    return FilledButton(
      onPressed: () => actions.accept(order),
      child: const Text('Accept'),
    );
  }
  if (order.canPack) {
    return FilledButton(
      onPressed: () => actions.pack(order),
      child: const Text('Pack'),
    );
  }
  if (order.canShip) {
    return FilledButton(
      onPressed: () => actions.ship(order),
      child: const Text('Ship'),
    );
  }
  if (order.canDeliver) {
    return OutlinedButton(
      onPressed: () => actions.markDelivered(order),
      child: const Text('Mark delivered'),
    );
  }
  return null;
}
