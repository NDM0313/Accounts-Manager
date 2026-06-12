import 'package:accounts_manager/core/export/report_pdf_builder.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

import 'receipt_redaction.dart';

export 'receipt_redaction.dart';

enum RemittanceReceiptType { customer, internal, agentSlip }

String formatRemittanceReceipt(
  FxRemittance r, {
  RemittanceReceiptType receiptType = RemittanceReceiptType.customer,
}) {
  final fmt = NumberFormat('#,##0.00');
  final dtFmt = DateFormat('dd MMM yyyy, HH:mm');
  final now = dtFmt.format(DateTime.now());
  final buf = StringBuffer();

  switch (receiptType) {
    case RemittanceReceiptType.agentSlip:
      buf
        ..writeln('FX Cash Ledger — Agent Payout Slip')
        ..writeln('─────────────────────────')
        ..writeln('RM: ${r.remittanceNo ?? r.trackingId}')
        ..writeln('Receiver: ${r.receiverName}')
        ..writeln('Payout: ${r.payoutCurrency} ${fmt.format(r.payoutAmount)}');
      if (r.payoutCode != null) buf.writeln('Payout code: ${r.payoutCode}');
      if (r.payoutAgentName != null) buf.writeln('Agent: ${r.payoutAgentName}');
      if (r.branchName != null) buf.writeln('Branch: ${r.branchName}');
      buf.writeln('Status: ${r.status.label}');
      if (r.payoutConfirmedAt != null) {
        buf.writeln('Paid at: ${dtFmt.format(r.payoutConfirmedAt!.toLocal())}');
      }
      buf.writeln('Printed: $now');
      break;
    case RemittanceReceiptType.internal:
      buf
        ..writeln('FX Cash Ledger — Remittance Receipt (Internal)')
        ..writeln('─────────────────────────')
        ..writeln('RM: ${r.remittanceNo ?? r.trackingId}')
        ..writeln('Tracking: ${r.trackingId}')
        ..writeln('Status: ${r.status.label}')
        ..writeln('Sender: ${r.senderName ?? '—'}')
        ..writeln('Receiver: ${r.receiverName}');
      if (r.receiverPhone != null) buf.writeln('Phone: ${r.receiverPhone}');
      if (r.branchName != null) buf.writeln('Branch: ${r.branchName}');
      buf
        ..writeln()
        ..writeln(
          'Receive: ${r.receiveCurrency} ${fmt.format(r.receiveAmount)}',
        )
        ..writeln('Payout: ${r.payoutCurrency} ${fmt.format(r.payoutAmount)}')
        ..writeln(
          'Commission: ${fmt.format(r.commissionAmount)} (${r.commissionMode.label})',
        )
        ..writeln('Total payable: ${fmt.format(r.totalPayable)}')
        ..writeln('Paid: ${fmt.format(r.paidAmount)}')
        ..writeln('Balance due: ${fmt.format(r.balanceDue)}');
      if (r.notes != null && r.notes!.isNotEmpty) {
        buf.writeln('Notes: ${r.notes}');
      }
      buf.writeln('Printed: $now');
      break;
    case RemittanceReceiptType.customer:
      buf
        ..writeln('FX Cash Ledger — Remittance Receipt')
        ..writeln('─────────────────────────')
        ..writeln('Reference: ${r.trackingId}')
        ..writeln('Status: ${r.status.label}')
        ..writeln('Receiver: ${r.receiverName}');
      if (r.receiverPhone != null) buf.writeln('Phone: ${r.receiverPhone}');
      if (r.receiverCity != null || r.receiverCountry != null) {
        buf.writeln(
          'Location: ${[r.receiverCity, r.receiverCountry].whereType<String>().join(', ')}',
        );
      }
      buf
        ..writeln()
        ..writeln(
          'Receive: ${r.receiveCurrency} ${fmt.format(r.receiveAmount)}',
        )
        ..writeln('Payout: ${r.payoutCurrency} ${fmt.format(r.payoutAmount)}');
      if (r.commissionMode == FxRemittanceCommissionMode.customerPaid) {
        buf.writeln('Service charge included in payment.');
      }
      buf
        ..writeln('─────────────────────────')
        ..writeln('Retain this receipt for your records.')
        ..writeln('Printed: $now');
      break;
  }
  return buf.toString();
}

Future<Uint8List> buildRemittanceReceiptPdf(
  FxRemittance r, {
  RemittanceReceiptType receiptType = RemittanceReceiptType.customer,
}) {
  final title = switch (receiptType) {
    RemittanceReceiptType.agentSlip => 'Payout ${r.trackingId}',
    RemittanceReceiptType.internal => 'Remittance ${r.trackingId} (Internal)',
    RemittanceReceiptType.customer => 'Remittance ${r.trackingId}',
  };
  return buildReceiptPdf(
    receiptText: formatRemittanceReceipt(r, receiptType: receiptType),
    title: title,
  );
}

String formatAgentPaymentReceipt(FxTransaction tx, {bool customerCopy = true}) {
  return formatTransactionReceipt(tx, customerCopy: customerCopy);
}
