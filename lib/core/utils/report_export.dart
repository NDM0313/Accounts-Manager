import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:share_plus/share_plus.dart';

export 'transaction_receipt.dart' show formatTrialBalanceCsv;

String formatCoaCsv(List<FxAccount> accounts) {
  final buf = StringBuffer('Code,Name,Type,Active,Currency\n');
  for (final a in accounts) {
    buf.writeln(
      '${a.code},"${a.name.replaceAll('"', '""')}",${a.accountType},${a.isActive},${a.currencyCode ?? ''}',
    );
  }
  return buf.toString();
}

String formatBalanceSheetCsv(List<BalanceSheetRow> rows) {
  final buf = StringBuffer('Account Code,Account Name,Type,Balance PKR\n');
  for (final r in rows) {
    buf.writeln(
      '${r.accountCode},"${r.accountName.replaceAll('"', '""')}",${r.accountType},${r.balancePkr}',
    );
  }
  return buf.toString();
}

String formatProfitLossCsv(List<ProfitLossRow> rows) {
  final buf = StringBuffer('Account Code,Account Name,Type,Amount PKR\n');
  for (final r in rows) {
    buf.writeln(
      '${r.accountCode},"${r.accountName.replaceAll('"', '""')}",${r.accountType},${r.amountPkr}',
    );
  }
  return buf.toString();
}

Future<void> shareReportCsv({required String csv, required String subject}) {
  return SharePlus.instance.share(ShareParams(text: csv, subject: subject));
}
