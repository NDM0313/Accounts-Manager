import 'package:accounts_manager/core/export/receipt_redaction.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:share_plus/share_plus.dart';

export 'package:accounts_manager/core/export/receipt_redaction.dart' show formatTransactionReceipt;

Future<void> shareTransactionReceipt(FxTransaction tx, {String? subject, bool customerCopy = false}) {
  return SharePlus.instance.share(ShareParams(
    text: formatTransactionReceipt(tx, customerCopy: customerCopy),
    subject: subject ?? 'FX Ledger Receipt ${tx.transactionNo ?? tx.id.substring(0, 8)}',
  ));
}
