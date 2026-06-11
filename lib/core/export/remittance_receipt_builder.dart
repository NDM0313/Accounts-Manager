import 'package:accounts_manager/core/export/report_pdf_builder.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

import 'receipt_redaction.dart';

export 'receipt_redaction.dart';

String formatRemittanceReceipt(FxRemittance r, {bool customerCopy = true}) {
  final fmt = NumberFormat('#,##0.00');
  final buf = StringBuffer()
    ..writeln('FX Cash Ledger — Remittance Receipt')
    ..writeln('─────────────────────────')
    ..writeln('Tracking: ${r.trackingId}')
    ..writeln('Status: ${r.status.label}')
    ..writeln('Receiver: ${r.receiverName}');
  if (r.receiverPhone != null) buf.writeln('Phone: ${r.receiverPhone}');
  if (r.receiverCity != null || r.receiverCountry != null) {
    buf.writeln('Location: ${[r.receiverCity, r.receiverCountry].whereType<String>().join(', ')}');
  }
  buf
    ..writeln()
    ..writeln('Receive: ${r.receiveCurrency} ${fmt.format(r.receiveAmount)}')
    ..writeln('Payout: ${r.payoutCurrency} ${fmt.format(r.payoutAmount)}')
    ..writeln('Rate: ${fmt.format(r.exchangeRate)}');
  if (!customerCopy) {
    buf
      ..writeln('Commission: ${fmt.format(r.commissionAmount)}')
      ..writeln('Total payable: ${fmt.format(r.totalPayable)}')
      ..writeln('Paid: ${fmt.format(r.paidAmount)}');
    if (r.notes != null && r.notes!.isNotEmpty) buf.writeln('Notes: ${r.notes}');
  }
  buf.writeln('─────────────────────────');
  if (customerCopy) {
    buf.writeln('Retain this receipt for your records.');
  } else {
    buf.writeln('Internal copy — includes commission and notes.');
  }
  return buf.toString();
}

Future<Uint8List> buildRemittanceReceiptPdf(FxRemittance r, {bool customerCopy = true}) {
  return buildReceiptPdf(
    receiptText: formatRemittanceReceipt(r, customerCopy: customerCopy),
    title: 'Remittance ${r.trackingId}',
  );
}

String formatAgentPaymentReceipt(FxTransaction tx, {bool customerCopy = true}) {
  return formatTransactionReceipt(tx, customerCopy: customerCopy);
}
