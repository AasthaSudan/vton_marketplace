import 'dart:typed_data';

import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

typedef PrintPdf = Future<void> Function(Uint8List bytes, String name);

/// Opens the browser's print dialog (replaced in tests).
final printPdfProvider = Provider<PrintPdf>(
  (ref) =>
      (bytes, name) => Printing.layoutPdf(onLayout: (_) => bytes, name: name),
);

String _rupees(Object? paise) =>
    CurrencyFormatter.format((paise as num? ?? 0).toInt())
    // The built-in PDF fonts have no ₹ glyph.
    .replaceAll('₹', 'Rs. ');

String _address(Map<String, dynamic> a) => [
  a['name'],
  a['line1'],
  a['line2'],
  [
    a['city'],
    a['state'],
    a['pin_code'],
  ].where((p) => p != null && '$p'.isNotEmpty).join(', '),
  a['phone'],
].where((p) => p != null && '$p'.isNotEmpty).join('\n');

/// A tax invoice (page 1) and a packing label (page 2) for a packed order,
/// from seller_order_invoice. Prices include GST; the tax is shown per line.
Future<Uint8List> buildInvoicePdf(Map<String, dynamic> invoice) async {
  final seller = (invoice['seller'] as Map).cast<String, dynamic>();
  final buyer = (invoice['buyer'] as Map).cast<String, dynamic>();
  final totals = (invoice['totals'] as Map).cast<String, dynamic>();
  final lines = (invoice['lines'] as List)
      .map((l) => (l as Map).cast<String, dynamic>())
      .toList();
  final shipment = (invoice['shipment'] as Map?)?.cast<String, dynamic>();
  final intra = invoice['intra_state'] == true;
  final cod = (invoice['cod_amount'] as num? ?? 0).toInt();

  final small = pw.TextStyle(fontSize: 8, color: PdfColors.grey700);
  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);

  final doc = pw.Document(title: 'Invoice ${invoice['invoice_number']}');

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    seller['legal_name'] as String? ?? '',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(_address(seller), style: small),
                  if (seller['gstin'] != null)
                    pw.Text('GSTIN ${seller['gstin']}', style: small),
                  if (seller['pan'] != null)
                    pw.Text('PAN ${seller['pan']}', style: small),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'TAX INVOICE',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('No. ${invoice['invoice_number']}'),
                  pw.Text('Date ${invoice['invoice_date']}'),
                  pw.Text('Order ${invoice['reference']}', style: small),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Bill to / Ship to', style: bold),
          pw.Text(_address(buyer)),
          pw.Text(
            'Place of supply: ${invoice['place_of_supply']}',
            style: small,
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              for (var i = 2; i < 9; i++) i: pw.Alignment.centerRight,
            },
            headers: [
              'Item',
              'HSN',
              'Qty',
              'Rate',
              'GST',
              'Taxable',
              if (intra) ...['CGST', 'SGST'] else 'IGST',
              'Total',
            ],
            data: [
              for (final l in lines)
                [
                  '${l['title']}\n${l['variant']} · SKU ${l['sku']}',
                  l['hsn_code'] ?? '',
                  '${l['quantity']}',
                  _rupees(l['unit_price']),
                  '${((l['gst_rate_bps'] as num) / 100).toStringAsFixed(0)}%',
                  _rupees(l['taxable_value']),
                  if (intra) ...[
                    _rupees(l['cgst']),
                    _rupees(l['sgst']),
                  ] else
                    _rupees(l['igst']),
                  _rupees(l['total']),
                ],
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Taxable value ${_rupees(totals['taxable_value'])}'),
                if (intra) ...[
                  pw.Text('CGST ${_rupees(totals['cgst'])}'),
                  pw.Text('SGST ${_rupees(totals['sgst'])}'),
                ] else
                  pw.Text('IGST ${_rupees(totals['igst'])}'),
                pw.Text(
                  'Invoice total ${_rupees(totals['total'])}',
                  style: bold,
                ),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'Prices include GST. Sold by ${seller['legal_name']} through '
            'Clothsy. This is a computer-generated invoice.',
            style: small,
          ),
        ],
      ),
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6,
      margin: const pw.EdgeInsets.all(16),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            cod > 0 ? 'COD — COLLECT ${_rupees(cod)}' : 'PREPAID',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Deliver to', style: small),
          pw.Text(_address(buyer), style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 8),
          pw.Text('From', style: small),
          pw.Text(
            _address({...seller, 'name': seller['name']}),
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 8),
          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: '${invoice['reference']}',
            height: 40,
          ),
          if (shipment?['tracking_number'] != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              '${shipment!['carrier']} · AWB ${shipment['tracking_number']}',
            ),
          ],
          pw.Text(
            'Order ${invoice['reference']} · Invoice ${invoice['invoice_number']}',
            style: small,
          ),
        ],
      ),
    ),
  );

  return doc.save();
}
