import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/domain/models/account_statement.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/services/reporting_currency_converter.dart';
import 'package:share_plus/share_plus.dart';

export 'transaction_receipt.dart'
    show formatTransactionReceipt, shareTransactionReceipt;

String formatCoaCsv(List<FxAccount> accounts) {
  final buf = StringBuffer('Code,Name,Type,Active,Currency\n');
  for (final a in accounts) {
    buf.writeln(
      '${a.code},"${a.name.replaceAll('"', '""')}",${a.accountType},${a.isActive},${a.currencyCode ?? ''}',
    );
  }
  return buf.toString();
}

String formatTrialBalanceCsv(
  List<TrialBalanceRow> rows, {
  ReportingCurrencyConverter? converter,
  ReportCurrencyView view = ReportCurrencyView.base,
}) {
  final includeDisplay =
      converter != null &&
      !converter.isDisplayBase &&
      view != ReportCurrencyView.base;
  final buf = StringBuffer(
    includeDisplay
        ? 'Account Code,Account Name,Debit PKR,Credit PKR,Net PKR,Net Display\n'
        : 'Account Code,Account Name,Debit PKR,Credit PKR,Net PKR\n',
  );
  for (final r in rows) {
    if (includeDisplay) {
      final displayNet = _displayAmount(r.netPkr, converter, view);
      buf.writeln(
        '${r.accountCode},"${r.accountName.replaceAll('"', '""')}",${r.debitPkr},${r.creditPkr},${r.netPkr},$displayNet',
      );
    } else {
      buf.writeln(
        '${r.accountCode},"${r.accountName.replaceAll('"', '""')}",${r.debitPkr},${r.creditPkr},${r.netPkr}',
      );
    }
  }
  return buf.toString();
}

String formatBalanceSheetCsv(
  List<BalanceSheetRow> rows, {
  ReportingCurrencyConverter? converter,
  ReportCurrencyView view = ReportCurrencyView.base,
}) {
  final includeDisplay =
      converter != null &&
      !converter.isDisplayBase &&
      view != ReportCurrencyView.base;
  final buf = StringBuffer(
    includeDisplay
        ? 'Account Code,Account Name,Type,Balance PKR,Balance Display\n'
        : 'Account Code,Account Name,Type,Balance PKR\n',
  );
  for (final r in rows) {
    if (includeDisplay) {
      buf.writeln(
        '${r.accountCode},"${r.accountName.replaceAll('"', '""')}",${r.accountType},${r.balancePkr},${_displayAmount(r.balancePkr, converter, view)}',
      );
    } else {
      buf.writeln(
        '${r.accountCode},"${r.accountName.replaceAll('"', '""')}",${r.accountType},${r.balancePkr}',
      );
    }
  }
  return buf.toString();
}

String formatProfitLossCsv(
  List<ProfitLossRow> rows, {
  ReportingCurrencyConverter? converter,
  ReportCurrencyView view = ReportCurrencyView.base,
}) {
  final includeDisplay =
      converter != null &&
      !converter.isDisplayBase &&
      view != ReportCurrencyView.base;
  final buf = StringBuffer(
    includeDisplay
        ? 'Account Code,Account Name,Type,Amount PKR,Amount Display\n'
        : 'Account Code,Account Name,Type,Amount PKR\n',
  );
  for (final r in rows) {
    if (includeDisplay) {
      buf.writeln(
        '${r.accountCode},"${r.accountName.replaceAll('"', '""')}",${r.accountType},${r.amountPkr},${_displayAmount(r.amountPkr, converter, view)}',
      );
    } else {
      buf.writeln(
        '${r.accountCode},"${r.accountName.replaceAll('"', '""')}",${r.accountType},${r.amountPkr}',
      );
    }
  }
  return buf.toString();
}

String formatCurrencyPositionCsv(
  List<CurrencyPositionRow> rows, {
  ReportingCurrencyConverter? converter,
  ReportCurrencyView view = ReportCurrencyView.base,
}) {
  final includeDisplay =
      converter != null &&
      !converter.isDisplayBase &&
      view != ReportCurrencyView.base;
  final buf = StringBuffer(
    includeDisplay
        ? 'Currency,Foreign Balance,PKR Equivalent,Display Equivalent\n'
        : 'Currency,Foreign Balance,PKR Equivalent\n',
  );
  for (final r in rows) {
    if (includeDisplay) {
      buf.writeln(
        '${r.currencyCode},${r.foreignBalance},${r.baseEquivalentPkr},${_displayAmount(r.baseEquivalentPkr, converter, view)}',
      );
    } else {
      buf.writeln(
        '${r.currencyCode},${r.foreignBalance},${r.baseEquivalentPkr}',
      );
    }
  }
  return buf.toString();
}

String formatAccountStatementCsv(
  AccountStatementView view, {
  ReportingCurrencyConverter? converter,
  ReportCurrencyView viewMode = ReportCurrencyView.base,
}) {
  final includeDisplay =
      converter != null &&
      !converter.isDisplayBase &&
      viewMode != ReportCurrencyView.base;
  final buf = StringBuffer(
    includeDisplay
        ? 'Date,Ref,Description,Debit PKR,Credit PKR,Balance PKR,Balance Display\n'
        : 'Date,Ref,Description,Debit PKR,Credit PKR,Balance PKR\n',
  );
  for (final l in view.lines) {
    if (includeDisplay) {
      buf.writeln(
        '${l.entryDate.toIso8601String().split('T').first},${l.entryNo},"${(l.description ?? '').replaceAll('"', '""')}",${l.debitPkr},${l.creditPkr},${l.runningBalancePkr},${_displayAmount(l.runningBalancePkr, converter, viewMode)}',
      );
    } else {
      buf.writeln(
        '${l.entryDate.toIso8601String().split('T').first},${l.entryNo},"${(l.description ?? '').replaceAll('"', '""')}",${l.debitPkr},${l.creditPkr},${l.runningBalancePkr}',
      );
    }
  }
  return buf.toString();
}

String formatDailyClosingCsv(List<ClosingPreviewRow> rows) {
  final buf = StringBuffer(
    'Account Code,Account Name,Currency,Closing Balance\n',
  );
  for (final r in rows) {
    buf.writeln(
      '${r.accountCode},"${r.accountName.replaceAll('"', '""')}",${r.currencyCode},${r.systemBalance}',
    );
  }
  return buf.toString();
}

String _displayAmount(
  double pkrAmount,
  ReportingCurrencyConverter converter,
  ReportCurrencyView view,
) {
  if (view == ReportCurrencyView.base) return pkrAmount.toStringAsFixed(2);
  final c = converter.convertFromPkr(pkrAmount);
  if (view == ReportCurrencyView.display) {
    return c.displayAmount.toStringAsFixed(2);
  }
  return '${pkrAmount.toStringAsFixed(2)} / ${c.displayAmount.toStringAsFixed(2)}';
}

Future<void> shareReportCsv({required String csv, required String subject}) {
  return SharePlus.instance.share(ShareParams(text: csv, subject: subject));
}
