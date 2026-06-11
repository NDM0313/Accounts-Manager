import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:intl/intl.dart';

enum ReceiptCopyMode { customer, internal }

/// Formats transaction receipt with optional redaction for customer-facing copies.
String formatTransactionReceipt(FxTransaction tx, {bool customerCopy = false}) {
  return formatTransactionReceiptWithMode(
    tx,
    mode: customerCopy ? ReceiptCopyMode.customer : ReceiptCopyMode.internal,
  );
}

String formatTransactionReceiptWithMode(FxTransaction tx, {required ReceiptCopyMode mode}) {
  final fmt = NumberFormat('#,##0.00');
  final dtFmt = DateFormat('d MMM yyyy • HH:mm');
  final ts = tx.postedAt ?? tx.createdAt ?? tx.transactionDate;
  final isAgentPayment = tx.transactionType == FxTransactionType.settlementSend;

  final buf = StringBuffer()
    ..writeln(isAgentPayment ? 'FX Cash Ledger — Agent Payment Receipt' : 'FX Cash Ledger — Payment Receipt')
    ..writeln('─────────────────────────')
    ..writeln('Ref: ${tx.transactionNo ?? tx.id.substring(0, 8).toUpperCase()}')
    ..writeln('Type: ${tx.transactionType.label}')
    ..writeln('Date: ${dtFmt.format(ts.toLocal())}')
    ..writeln()
    ..writeln('Amount: ${tx.currencyCode} ${fmt.format(tx.totalForeignAmount)}');

  if (mode == ReceiptCopyMode.internal) {
    buf
      ..writeln('PKR: ${fmt.format(tx.totalBaseAmountPkr)}')
      ..writeln('Rate: ${fmt.format(tx.rateUsed)}')
      ..writeln('Status: ${tx.status}');
    final fromLine = tx.lines.where((l) => l.debitPkr > 0).firstOrNull;
    final toLine = tx.lines.where((l) => l.creditPkr > 0).firstOrNull;
    if (fromLine != null) {
      buf.writeln('From: ${fromLine.accountCode ?? ''} ${fromLine.accountName ?? ''}'.trim());
    }
    if (toLine != null) {
      buf.writeln('To: ${toLine.accountCode ?? ''} ${toLine.accountName ?? ''}'.trim());
    }
    if (tx.description != null && tx.description!.isNotEmpty) {
      buf.writeln('Notes: ${tx.description}');
    }
  } else {
    if (tx.partyName != null) buf.writeln('Party: ${tx.partyName}');
    if (tx.description != null && tx.description!.isNotEmpty && !tx.description!.toLowerCase().contains('internal')) {
      buf.writeln('Notes: ${tx.description}');
    }
  }

  buf.writeln('─────────────────────────');
  return buf.toString();
}
