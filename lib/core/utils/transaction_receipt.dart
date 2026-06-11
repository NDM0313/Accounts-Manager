import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Plain-text receipt for Share / print-style export (no PDF in v1).
String formatTransactionReceipt(FxTransaction tx) {
  final fmt = NumberFormat('#,##0.00');
  final dtFmt = DateFormat('d MMM yyyy • HH:mm');
  final ts = tx.postedAt ?? tx.createdAt ?? tx.transactionDate;
  final fromLine = tx.lines.where((l) => l.debitPkr > 0).firstOrNull;
  final toLine = tx.lines.where((l) => l.creditPkr > 0).firstOrNull;

  final buf = StringBuffer()
    ..writeln('FX Cash Ledger — Receipt')
    ..writeln('─────────────────────────')
    ..writeln('Ref: ${tx.transactionNo ?? tx.id.substring(0, 8).toUpperCase()}')
    ..writeln('Type: ${tx.transactionType.label}')
    ..writeln('Status: ${tx.status}')
    ..writeln('Date: ${dtFmt.format(ts.toLocal())}')
    ..writeln()
    ..writeln('Amount: ${tx.currencyCode} ${fmt.format(tx.totalForeignAmount)}')
    ..writeln('PKR: ${fmt.format(tx.totalBaseAmountPkr)}')
    ..writeln('Rate: ${fmt.format(tx.rateUsed)}');

  if (fromLine != null) {
    buf.writeln('From: ${fromLine.accountCode ?? ''} ${fromLine.accountName ?? ''}'.trim());
  }
  if (toLine != null) {
    buf.writeln('To: ${toLine.accountCode ?? ''} ${toLine.accountName ?? ''}'.trim());
  }
  if (tx.description != null && tx.description!.isNotEmpty) {
    buf.writeln('Notes: ${tx.description}');
  }

  buf.writeln('─────────────────────────');
  return buf.toString();
}

Future<void> shareTransactionReceipt(FxTransaction tx, {String? subject}) {
  return SharePlus.instance.share(ShareParams(
    text: formatTransactionReceipt(tx),
    subject: subject ?? 'FX Ledger Receipt ${tx.transactionNo ?? tx.id.substring(0, 8)}',
  ));
}
